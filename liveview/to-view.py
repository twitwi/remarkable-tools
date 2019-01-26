
import os
import re
import sys
import asyncio
import websockets
from rm2svg import main as rm2svg

# waiting for the command to end, returning the return value
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
async def notify_all(msg, all=all):
    a = all.copy()
    all[:] = []
    for ws in a:
        try:
            await ws.send(msg)
            all.append(ws)
        except:
            pass

async def rebuild_svg(file_rm, file_svg, notify=True):
    try:
        rm2svg(["-c", "-i", file_rm, "-o", file_svg])
    except:
        print("ERROR WITH RUNNING RM->SVG")

    if notify:
        await notify_all("svg")

pdf = False
async def log(websocket, path):
    global pdf
    print("START LOG", websocket)
    if pdf:
        await notify_all("background", all=[websocket])
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

async def parse_input(ws_sv, file_rm, file_svg, file_pdf, convert_pdf_page_autorotate):
    global pdf
    while True:

        try:
            line = await asyncio.get_event_loop().run_in_executor(None, read_line)
        except:
            print("ERR", line)
            continue

        print("LINE:", line, len(all))

        if line == "FULL":
            count = await asyncio.get_event_loop().run_in_executor(None, read_line)
            count = int(count)
            print("READING FULL", count)
            data = await asyncio.get_event_loop().run_in_executor(None, read_chunk_from_stdin(count))
            print("READ", len(data))
            with open(file_rm, 'wb') as f:
                f.write(data)
            await asyncio.get_event_loop().run_in_executor(None, read_line) # read END
            await rebuild_svg(file_rm, file_svg)
        elif line == "PAGE":
            # full path to the .rm file
            page = await asyncio.get_event_loop().run_in_executor(None, read_line)
            page = re.sub(r'.*/', '', page)[:-3]
            if pdf:
                run_cmd(convert_pdf_page_autorotate, file_pdf, page, file_pdf+'-'+page+'.png')
                await notify_all("background:"+str(page))
        elif line == "NOPDF":
            pdf = False
            await notify_all("rmbackground")
        elif line == "PDF":
            count = await asyncio.get_event_loop().run_in_executor(None, read_line)
            count = int(count)
            print("READING PDF", count)
            pdf = True
            data = await asyncio.get_event_loop().run_in_executor(None, read_chunk_from_stdin(count))
            print("READ", len(data))
            with open(file_pdf, 'wb') as f:
                f.write(data)
            await asyncio.get_event_loop().run_in_executor(None, read_line) # read END
        elif line == "PATCH":
            print("LINE", line)
            patch = {}
            more = b''
            while True:
                line = await asyncio.get_event_loop().run_in_executor(None, read_line)
                if line == "APPEND":
                    count = await asyncio.get_event_loop().run_in_executor(None, read_line)
                    count = int(count)
                    print("READING", count)
                    more = await asyncio.get_event_loop().run_in_executor(None, read_chunk_from_stdin(count))
                elif line == "TRUNC":
                    size = await asyncio.get_event_loop().run_in_executor(None, read_line)
                    size = int(size)
                    print("TRUNC to", size)
                    with open(file_rm, 'rb') as f:
                        content = f.read()
                    with open(file_rm, 'wb') as f:
                        f.write(content[:size])
                elif line == "END":
                    break
                else:
                    els = line.replace('  ', ' ').replace('  ', ' ').split(" ")
                    if len(els) == 3:
                        patch[int(els[0])] = int(els[2], 8)

            with open(file_rm, 'rb') as f:
                content = bytearray(f.read())
            for k,v in patch.items():
                try:
                    content[k-1] = v
                except:
                    print("ERR PATCH", k, v)
            content += more
            with open(file_rm, 'wb') as f:
                f.write(content)
            await rebuild_svg(file_rm, file_svg)

        print(len(all))
        #await ws_server.send("SALUT!\n")

#inreader = asyncio.StreamReader(sys.stdin)
ws_server = websockets.serve(log, 'localhost', 4257)

asyncio.ensure_future(ws_server)
asyncio.ensure_future(parse_input(ws_server, *sys.argv[1:]))
asyncio.get_event_loop().run_forever()

# TODO write a rm2svg that reads from stdin (maybe) and ... set TODO
