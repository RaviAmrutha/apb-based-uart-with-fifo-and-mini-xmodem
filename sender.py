import socket
import os
import matplotlib.pyplot as plt

#  CHANGE THIS TO RECEIVER IP
SERVER_IP = "192.168.1.10"  
PORT = 5001
BUFFER_SIZE = 1024

tx_bits = []

def record_uart(byte):
    frame = [0] + [(byte >> i) & 1 for i in range(8)] + [1]
    tx_bits.extend(frame)

filename = "sample.pdf"

filesize = os.path.getsize(filename)

client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
client.connect((SERVER_IP, PORT))

client.send(filename.encode())
client.recv(1024)

client.send(str(filesize).encode())
client.recv(1024)

with open(filename, "rb") as f:
    while True:
        data = f.read(BUFFER_SIZE)
        if not data:
            break

        client.sendall(data)

        for b in data:
            record_uart(b)

print("\n[TX] File sent successfully")

client.close()

# TX waveform
MAX_BITS = 200
plt.step(range(len(tx_bits[:MAX_BITS])), tx_bits[:MAX_BITS], where='post')
plt.title("TX UART Waveform")
plt.ylim(-0.5, 1.5)
plt.grid()
plt.show()
