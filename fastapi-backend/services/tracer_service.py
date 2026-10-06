import os
import re
import secrets
import time
import asyncio
import logging
import httpx
from typing import Optional, Dict, Any

logger = logging.getLogger("fastkirana.tracer")

# W3C TraceContext regex: version(2 hex)-traceId(32 hex)-spanId(16 hex)-traceFlags(2 hex)
W3C_TRACEPARENT_REGEX = re.compile(r"^00-([a-f0-9]{32})-([a-f0-9]{16})-([a-f0-9]{2})$")


class TracerService:
    """
    W3C TraceContext & OpenTelemetry compliant Distributed Tracer.
    Connects:
      Flutter Checkout Tap
      -> FastAPI Calculation Engine
      -> Supabase Realtime Broadcast / WebSockets
      -> Rider Device Receipt

    Supports optional OpenTelemetry Collector (OTLP) export to
    SigNoz, Grafana Tempo, Datadog, or any standard OTLP endpoint via HTTP.
    """

    @staticmethod
    def get_otlp_endpoint() -> Optional[str]:
        """Returns configured OTLP HTTP traces endpoint, if any."""
        endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") or os.getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
        if not endpoint:
            return None
        endpoint = endpoint.strip()
        if not endpoint.endswith("/v1/traces"):
            endpoint = endpoint.rstrip("/") + "/v1/traces"
        return endpoint

    @staticmethod
    def get_service_name() -> str:
        return os.getenv("OTEL_SERVICE_NAME", "fastkirana-backend")

    @staticmethod
    def generate_trace_id() -> str:
        """Generates a compliant 32-char hex (128-bit) trace ID."""
        return secrets.token_hex(16)

    @staticmethod
    def generate_span_id() -> str:
        """Generates a compliant 16-char hex (64-bit) span ID."""
        return secrets.token_hex(8)

    @classmethod
    def parse_trace_headers(cls, headers: Dict[str, str]) -> Dict[str, Optional[str]]:
        """
        Parses incoming HTTP/WebSocket headers for W3C traceparent or X-Trace-Id.
        Returns {'trace_id': ..., 'parent_span_id': ..., 'is_new': bool}
        """
        traceparent = headers.get("traceparent") or headers.get("trace-parent")
        if traceparent:
            match = W3C_TRACEPARENT_REGEX.match(traceparent.strip().lower())
            if match:
                return {
                    "trace_id": match.group(1),
                    "parent_span_id": match.group(2),
                    "is_new": False,
                }

        explicit_trace_id = headers.get("x-trace-id") or headers.get("x-request-id")
        if explicit_trace_id:
            clean = re.sub(r"[^a-f0-9]", "", explicit_trace_id.lower())
            if len(clean) >= 32:
                return {"trace_id": clean[:32], "parent_span_id": None, "is_new": False}
            elif clean:
                return {"trace_id": clean.ljust(32, "0"), "parent_span_id": None, "is_new": False}

        return {
            "trace_id": cls.generate_trace_id(),
            "parent_span_id": None,
            "is_new": True,
        }

    @classmethod
    def format_traceparent(cls, trace_id: str, span_id: str, sampled: bool = True) -> str:
        """Formats W3C compliant traceparent header."""
        flags = "01" if sampled else "00"
        return f"00-{trace_id}-{span_id}-{flags}"

    @classmethod
    def start_span(
        cls,
        name: str,
        trace_id: Optional[str] = None,
        parent_span_id: Optional[str] = None,
        attributes: Optional[Dict[str, Any]] = None,
    ) -> "TraceSpan":
        t_id = trace_id or cls.generate_trace_id()
        s_id = cls.generate_span_id()
        return TraceSpan(
            name=name,
            trace_id=t_id,
            span_id=s_id,
            parent_span_id=parent_span_id,
            attributes=attributes or {},
            start_time=time.perf_counter(),
            start_time_unix_nano=time.time_ns(),
        )

    @classmethod
    async def export_otlp_span(
        cls,
        span: "TraceSpan",
        end_time_unix_nano: int,
        error: Optional[Any] = None,
    ) -> bool:
        """
        Exports span to OpenTelemetry Collector over standard OTLP JSON format.
        Fails silently and non-blockingly if collector is unreachable.
        """
        endpoint = cls.get_otlp_endpoint()
        if not endpoint:
            return False

        # Format attributes to OTLP KeyValue schema
        otlp_attributes = []
        for k, v in span.attributes.items():
            if isinstance(v, bool):
                val_dict = {"boolValue": v}
            elif isinstance(v, int):
                val_dict = {"intValue": str(v)}
            elif isinstance(v, float):
                val_dict = {"doubleValue": v}
            else:
                val_dict = {"stringValue": str(v)}
            otlp_attributes.append({"key": str(k), "value": val_dict})

        status = {
            "code": 2 if error else 1,  # 1 = OK, 2 = ERROR
            "message": str(error) if error else "",
        }

        otlp_payload = {
            "resourceSpans": [
                {
                    "resource": {
                        "attributes": [
                            {"key": "service.name", "value": {"stringValue": cls.get_service_name()}},
                            {"key": "service.version", "value": {"stringValue": "2.0.0"}},
                        ]
                    },
                    "scopeSpans": [
                        {
                            "scope": {"name": "fastkirana.tracer", "version": "1.0.0"},
                            "spans": [
                                {
                                    "traceId": span.trace_id,
                                    "spanId": span.span_id,
                                    "parentSpanId": span.parent_span_id or "",
                                    "name": span.name,
                                    "kind": 1,  # SPAN_KIND_INTERNAL
                                    "startTimeUnixNano": str(span.start_time_unix_nano),
                                    "endTimeUnixNano": str(end_time_unix_nano),
                                    "attributes": otlp_attributes,
                                    "status": status,
                                }
                            ],
                        }
                    ],
                }
            ]
        }

        headers = {"Content-Type": "application/json"}
        extra_headers = os.getenv("OTEL_EXPORTER_OTLP_HEADERS")
        if extra_headers:
            for pair in extra_headers.split(","):
                if "=" in pair:
                    hk, hv = pair.split("=", 1)
                    headers[hk.strip()] = hv.strip()

        try:
            async with httpx.AsyncClient(timeout=2.0) as client:
                res = await client.post(endpoint, json=otlp_payload, headers=headers)
                return res.status_code in [200, 202]
        except Exception as e:
            logger.debug(f"[OTLP Exporter] Non-blocking export notice: {e}")
            return False


class TraceSpan:
    def __init__(
        self,
        name: str,
        trace_id: str,
        span_id: str,
        parent_span_id: Optional[str] = None,
        attributes: Optional[Dict[str, Any]] = None,
        start_time: float = 0.0,
        start_time_unix_nano: int = 0,
    ):
        self.name = name
        self.trace_id = trace_id
        self.span_id = span_id
        self.parent_span_id = parent_span_id
        self.attributes = attributes or {}
        self.start_time = start_time or time.perf_counter()
        self.start_time_unix_nano = start_time_unix_nano or time.time_ns()
        logger.info(
            f"📡 [Tracer] [SPAN_START] name={name} trace_id={trace_id} span_id={span_id} parent={parent_span_id}"
        )

    @property
    def traceparent(self) -> str:
        return TracerService.format_traceparent(self.trace_id, self.span_id)

    @property
    def headers(self) -> Dict[str, str]:
        return {
            "X-Trace-Id": self.trace_id,
            "traceparent": self.traceparent,
        }

    def end(self, extra_attributes: Optional[Dict[str, Any]] = None, error: Optional[Any] = None) -> float:
        end_time_unix_nano = time.time_ns()
        duration_ms = (time.perf_counter() - self.start_time) * 1000.0
        self.attributes = {**self.attributes, **(extra_attributes or {})}
        if error:
            logger.error(
                f"💥 [Tracer] [SPAN_ERROR] name={self.name} trace_id={self.trace_id} span_id={self.span_id} duration={duration_ms:.2f}ms error={error} attrs={self.attributes}"
            )
        else:
            logger.info(
                f"✅ [Tracer] [SPAN_END] name={self.name} trace_id={self.trace_id} span_id={self.span_id} duration={duration_ms:.2f}ms attrs={self.attributes}"
            )

        # Trigger background non-blocking OTLP export if collector endpoint is configured
        if TracerService.get_otlp_endpoint():
            try:
                loop = asyncio.get_event_loop()
                if loop.is_running():
                    loop.create_task(TracerService.export_otlp_span(self, end_time_unix_nano, error))
            except Exception:
                pass

        return duration_ms
