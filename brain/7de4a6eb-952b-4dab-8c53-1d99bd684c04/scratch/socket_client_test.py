import socket

def run_client():
    try:
        client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        client_socket.connect(("localhost", 8000))

        print("Connected to server.")

        # For this automated test, we'll send a test message instead of waiting for input
        test_message = "GET /api/health HTTP/1.1\r\nHost: localhost\r\n\r\n"
        print(f"Sending: {test_message.strip()}")
        client_socket.send(test_message.encode())
        
        response = client_socket.recv(1024).decode()
        print(f"Server response: \n{response}")

        client_socket.close()
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    run_client()
