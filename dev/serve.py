import http.server, socketserver
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control","no-store"); super().end_headers()
socketserver.TCPServer.allow_reuse_address=True
socketserver.ThreadingTCPServer(("",8800),H).serve_forever()
