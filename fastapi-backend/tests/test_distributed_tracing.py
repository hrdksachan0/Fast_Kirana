import pytest
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.tracer_service import TracerService, W3C_TRACEPARENT_REGEX


class TestDistributedTracing:
    def test_w3c_trace_id_generation(self):
        trace_id = TracerService.generate_trace_id()
        assert len(trace_id) == 32
        assert all(c in "0123456789abcdef" for c in trace_id)

    def test_w3c_span_id_generation(self):
        span_id = TracerService.generate_span_id()
        assert len(span_id) == 16
        assert all(c in "0123456789abcdef" for c in span_id)

    def test_format_and_parse_traceparent(self):
        trace_id = TracerService.generate_trace_id()
        span_id = TracerService.generate_span_id()
        header = TracerService.format_traceparent(trace_id, span_id, sampled=True)
        assert W3C_TRACEPARENT_REGEX.match(header) is not None

        parsed = TracerService.parse_trace_headers({"traceparent": header})
        assert parsed["trace_id"] == trace_id
        assert parsed["parent_span_id"] == span_id
        assert parsed["is_new"] is False

    def test_parse_custom_x_trace_id(self):
        custom_id = "a" * 32
        parsed = TracerService.parse_trace_headers({"x-trace-id": custom_id})
        assert parsed["trace_id"] == custom_id
        assert parsed["is_new"] is False

    def test_start_and_end_span(self):
        span = TracerService.start_span("test_calc_span", attributes={"foo": "bar"})
        assert span.trace_id is not None
        assert span.span_id is not None
        assert "X-Trace-Id" in span.headers
        assert "traceparent" in span.headers
        duration = span.end(extra_attributes={"result": 100})
        assert duration >= 0.0

    def test_otlp_endpoint_parsing(self):
        os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"] = "http://collector.local:4318"
        endpoint = TracerService.get_otlp_endpoint()
        assert endpoint == "http://collector.local:4318/v1/traces"

        os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"] = "https://signoz.internal:4318/v1/traces"
        assert TracerService.get_otlp_endpoint() == "https://signoz.internal:4318/v1/traces"

        del os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"]
        assert TracerService.get_otlp_endpoint() is None

    @pytest.mark.asyncio
    async def test_otlp_export_graceful_fallback(self):
        os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"] = "http://127.0.0.1:49999"
        span = TracerService.start_span("otlp_test_span", attributes={"item": "milk", "count": 2})
        # Unreachable port 49999 should gracefully return False without raising an exception
        result = await TracerService.export_otlp_span(span, 1000000)
        assert result is False
        del os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"]


class TestAlembicPipeline:
    def test_alembic_configuration_exists(self):
        backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        ini_path = os.path.join(backend_dir, "alembic.ini")
        env_path = os.path.join(backend_dir, "alembic", "env.py")
        versions_dir = os.path.join(backend_dir, "alembic", "versions")

        assert os.path.exists(ini_path), "alembic.ini must exist"
        assert os.path.exists(env_path), "alembic/env.py must exist"
        assert os.path.isdir(versions_dir), "alembic/versions must exist"

        versions = [f for f in os.listdir(versions_dir) if f.endswith(".py")]
        assert len(versions) >= 1, "At least one baseline Alembic revision must be generated"
