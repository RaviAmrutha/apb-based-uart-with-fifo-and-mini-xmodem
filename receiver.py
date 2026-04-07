import socket
import matplotlib.pyplot as plt
import os

HOST = '0.0.0.0'   # listen on all interfaces
PORT = 5001
BUFFER_SIZE = 1024

rx_bits = []

def record_uart(byte):
    frame = [0] + [(byte >> i) & 1 for i in range(8)] + [1]
    rx_bits.extend(frame)

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.bind((HOST, PORT))
server.listen(1)

print("Receiver waiting...")

conn, addr = server.accept()
print("Connected to:", addr)

filename = conn.recv(1024).decode()
conn.send(b"OK")

filesize = int(conn.recv(1024).decode())
conn.send(b"OK")

received = 0

with open("received_" + filename, "wb") as f:
    while received < filesize:
        data = conn.recv(BUFFER_SIZE)
        if not data:
            break

        f.write(data)
        received += len(data)

        for b in data:
            record_uart(b)

print("\n[RX] ACK sent - File received successfully")

conn.close()
server.close()

# Open file
file_path = "received_" + filename
os.startfile(file_path)

# RX waveform
MAX_BITS = 200
plt.step(range(len(rx_bits[:MAX_BITS])), rx_bits[:MAX_BITS], where='post')
plt.title("RX UART Waveform")
plt.ylim(-0.5, 1.5)
plt.grid()
plt.show()
