from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query
from typing import Dict, List
import json
import asyncio

router = APIRouter(prefix="/ws", tags=["Real-time WebSockets Engine"])

class ConnectionManager:
    def __init__(self):
        # Active connections mapped by channel/room (e.g. order_id or rider_id)
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, channel_id: str):
        await websocket.accept()
        if channel_id not in self.active_connections:
            self.active_connections[channel_id] = []
        self.active_connections[channel_id].append(websocket)

    def disconnect(self, websocket: WebSocket, channel_id: str):
        if channel_id in self.active_connections:
            if websocket in self.active_connections[channel_id]:
                self.active_connections[channel_id].remove(websocket)
            if not self.active_connections[channel_id]:
                del self.active_connections[channel_id]

    async def broadcast_to_channel(self, channel_id: str, message: dict):
        if channel_id in self.active_connections:
            disconnected = []
            for connection in self.active_connections[channel_id]:
                try:
                    await connection.send_text(json.dumps(message))
                except Exception:
                    disconnected.append(connection)
            for conn in disconnected:
                self.disconnect(conn, channel_id)

manager = ConnectionManager()

@router.websocket("/orders/{order_id}")
async def order_tracking_websocket(websocket: WebSocket, order_id: str):
    """
    Live real-time order tracking WebSocket for customers & delivery riders
    """
    await manager.connect(websocket, f"order_{order_id}")
    try:
        while True:
            # Receive GPS ping or status update message
            data = await websocket.receive_text()
            payload = json.loads(data)
            
            # Broadcast location or status to all connected clients on this order channel
            await manager.broadcast_to_channel(f"order_{order_id}", {
                "event": payload.get("event", "LOCATION_UPDATE"),
                "orderId": order_id,
                "lat": payload.get("lat"),
                "lng": payload.get("lng"),
                "status": payload.get("status"),
                "timestamp": payload.get("timestamp")
            })
    except WebSocketDisconnect:
        manager.disconnect(websocket, f"order_{order_id}")

@router.websocket("/rider/{rider_id}")
async def rider_location_websocket(websocket: WebSocket, rider_id: str):
    """
    Real-time rider GPS stream for admin live operations tracking
    """
    await manager.connect(websocket, f"rider_{rider_id}")
    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)
            await manager.broadcast_to_channel(f"rider_{rider_id}", payload)
    except WebSocketDisconnect:
        manager.disconnect(websocket, f"rider_{rider_id}")
