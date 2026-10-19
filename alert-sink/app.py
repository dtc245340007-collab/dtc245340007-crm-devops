import http.server
import json
import sys
from datetime import datetime

received_alerts = []

class AlertHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"healthy"}\n')
        elif self.path == "/alerts":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(received_alerts).encode("utf-8"))
        else:
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"Alert-Sink Webhook Receiver is running.\n")

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length)
        timestamp = datetime.utcnow().isoformat() + "Z"
        
        try:
            payload = json.loads(post_data.decode("utf-8"))
        except Exception:
            payload = {"raw": post_data.decode("utf-8", errors="replace")}
            
        record = {
            "received_at": timestamp,
            "path": self.path,
            "payload": payload
        }
        received_alerts.append(record)
        
        # Log to STDOUT with clear banner for evidence tracing
        sys.stdout.write("\n=======================================================\n")
        sys.stdout.write(f"[ALERT-SINK] WEBHOOK ALERT RECEIVED AT {timestamp}\n")
        sys.stdout.write(f"Endpoint: {self.path}\n")
        sys.stdout.write("Alert Details:\n")
        
        if isinstance(payload, dict) and "alerts" in payload:
            for alert in payload.get("alerts", []):
                labels = alert.get("labels", {})
                annotations = alert.get("annotations", {})
                sys.stdout.write(f"  - Alert Name: {labels.get('alertname', 'Unknown')}\n")
                sys.stdout.write(f"    Status:     {alert.get('status', 'Unknown')}\n")
                sys.stdout.write(f"    Severity:   {labels.get('severity', 'Unknown')}\n")
                sys.stdout.write(f"    Summary:    {annotations.get('summary', 'No summary')}\n")
                sys.stdout.write(f"    Desc:       {annotations.get('description', 'No description')}\n")
                sys.stdout.write(f"    StartsAt:   {alert.get('startsAt', 'Unknown')}\n")
        else:
            sys.stdout.write(json.dumps(payload, indent=2) + "\n")
            
        sys.stdout.write("=======================================================\n\n")
        sys.stdout.flush()

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status":"received"}\n')

    def log_message(self, format, *args):
        sys.stdout.write(f"[ALERT-SINK HTTP] {self.address_string()} - {format % args}\n")
        sys.stdout.flush()

if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", 5000), AlertHandler)
    sys.stdout.write("Alert-Sink HTTP Webhook Server listening on port 5000...\n")
    sys.stdout.flush()
    server.serve_forever()
