
import os
import sys
import asyncio
import websockets
from rm2svg import main as rm2svg

sys.stdin = os.fdopen(sys.stdin.fileno(), 'rb', 0)

def read_line(f=sys.stdin):
    res = b''
    while True:
        b = f.read(1)
        if len(b) == 0:
            return None
        if b == b'\n':
            break
        res += b;
    return res.decode('utf-8')

all = []

async def log(websocket, path):
    print("START LOG", websocket)
    all.append(websocket)
    async for message in websocket:
        print("MESSAGE", message)
        #await websocket.send(message)
    print("END LOG")

def read_chunk_from_stdin(n):
    def sub():
        res = b''
        while len(res) < n:
            res += sys.stdin.read(n - len(res))
        return res
    return sub

async def parse_input(ws_sv, file_rm, file_svg):
    while True:
        try:
            line = await asyncio.get_event_loop().run_in_executor(None, read_line)
        except:
            print("ERR", line)
            continue
        print("LINE:", line, len(all))
        if line == "START":
            count = await asyncio.get_event_loop().run_in_executor(None, read_line)
            count = int(count)
            print("READING", count)
            data = await asyncio.get_event_loop().run_in_executor(None, read_chunk_from_stdin(count))
            print("READ", len(data))
            with open(file_rm, 'wb') as f:
                f.write(data)

            try:
                rm2svg(["-c", "-i", file_rm, "-o", file_svg])
            except:
                print("ERROR WITH RUNNING RM->SVG")

            a = all.copy()
            all[:] = []
            for ws in a:
                try:
                    await ws.send("Salut "+str(len(all)))
                    all.append(ws)
                except:
                    pass

        print(len(all))
        #await ws_server.send("SALUT!\n")

#inreader = asyncio.StreamReader(sys.stdin)
ws_server = websockets.serve(log, 'localhost', 4257)

asyncio.ensure_future(ws_server)
asyncio.ensure_future(parse_input(ws_server, sys.argv[1], sys.argv[2]))
asyncio.get_event_loop().run_forever()

# TODO write a rm2svg that reads from stdin (maybe) and ... set TODO
