
import os
import sys
import asyncio
import websockets

import subprocess
def run_cmd(*args):
    return subprocess.call(args)


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

async def parse_input(ws_sv):
    while True:
        try:
            line = await asyncio.get_event_loop().run_in_executor(None, read_line)
        except e:
            print("ERR", e, line)
            continue
        print("LINE:", line, len(all))
        if line == "START":
            count = await asyncio.get_event_loop().run_in_executor(None, read_line)
            count = int(count)
            print("READING", count)
            data = await asyncio.get_event_loop().run_in_executor(None, read_chunk_from_stdin(count))
            print("READ", len(data))
            with open('TOTO.rm', 'wb') as f:
                f.write(data)
            run_cmd("python3", "rm2svg.py", "-c", "-i", "TOTO.rm", "-o", "TOTO.svg")
            for ws in all:
                await ws.send("Salut "+str(len(all)))
        print(len(all))
        #await ws_server.send("SALUT!\n")

#inreader = asyncio.StreamReader(sys.stdin)
ws_server = websockets.serve(log, 'localhost', 4257)

asyncio.ensure_future(ws_server)
asyncio.ensure_future(parse_input(ws_server))
asyncio.get_event_loop().run_forever()

# TODO write a rm2svg that reads from stdin (maybe) and ... set TODO
