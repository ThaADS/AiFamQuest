from fastapi import APIRouter, WebSocket, WebSocketDisconnect
router = APIRouter()
class Hub:
    def __init__(self): self.rooms = {}
    async def connect(self, ws: WebSocket, room: str):
        await ws.accept(); self.rooms.setdefault(room, set()).add(ws)
    async def broadcast(self, room: str, data: dict):
        dead = set()
        for ws in self.rooms.get(room, set()):
            try: await ws.send_json(data)
            except Exception: dead.add(ws)
        for d in dead: self.rooms[room].discard(d)
hub = Hub()
@router.websocket("/ws/{familyId}")
async def ws_endpoint(ws: WebSocket, familyId: str):
    await hub.connect(ws, familyId)
    try:
        while True:
            msg = await ws.receive_json()
            await hub.broadcast(familyId, msg)
    except WebSocketDisconnect:
        pass
