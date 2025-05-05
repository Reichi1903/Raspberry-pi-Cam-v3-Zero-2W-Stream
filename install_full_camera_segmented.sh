#!/bin/bash

echo "=== Raspberry Pi Kamera Vollinstallation mit 15-Minuten-Segmentierung ==="

# 1. Pakete installieren
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3-flask python3-picamera2 libcamera-apps ffmpeg nginx apache2-utils

# 2. Verzeichnisse
mkdir -p ~/pi-cam-web/templates ~/recordings

# 3. HTML-Weboberfläche
cat > ~/pi-cam-web/templates/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Raspberry Pi Kamera</title>
    <style>
        body { font-family: sans-serif; text-align: center; }
        img { width: 90%; max-width: 720px; }
        button { padding: 10px; margin: 5px; font-size: 16px; }
    </style>
</head>
<body>
    <h2>Live Kamera</h2>
    <img src="{{ url_for('video_feed') }}" />

    <div>
        <button onclick="fetch('/start')">Start Stream</button>
        <button onclick="fetch('/stop')">Stop Stream</button>
        <button onclick="fetch('/focus')">Autofokus</button>
        <button onclick="fetch('/zoom_in')">Zoom +</button>
        <button onclick="fetch('/zoom_out')">Zoom −</button>
    </div>
    <br>
    <a href="/recordings" target="_blank">Aufnahmen öffnen (geschützt)</a>
</body>
</html>
EOF

# 4. Python-Webserver
cat > ~/pi-cam-web/app.py << 'EOF'
from flask import Flask, render_template, Response
import subprocess
from picamera2 import Picamera2

app = Flask(__name__)
camera = Picamera2()
streaming = False
zoom_level = 1.0

def generate_frames():
    camera.configure(camera.create_preview_configuration())
    camera.start()
    while True:
        frame = camera.capture_array("main")
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame.tobytes() + b'\r\n')

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/video_feed')
def video_feed():
    return Response(generate_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/start')
def start_stream():
    global streaming
    if not streaming:
        subprocess.Popen([
            "libcamera-vid", "-t", "0", "--width", "4608", "--height", "2592",
            "--framerate", "10", "--codec", "h264", "--inline",
            "--output", "-"], stdout=subprocess.DEVNULL)
        streaming = True
    return ('', 204)

@app.route('/stop')
def stop_stream():
    subprocess.run(["pkill", "-f", "libcamera-vid"])
    global streaming
    streaming = False
    return ('', 204)

@app.route('/focus')
def focus():
    subprocess.run(["libcamera-ctl", "--autofocus", "start"])
    return ('', 204)

@app.route('/zoom_in')
def zoom_in():
    global zoom_level
    zoom_level = min(zoom_level + 0.1, 2.0)
    return ('', 204)

@app.route('/zoom_out')
def zoom_out():
    global zoom_level
    zoom_level = max(zoom_level - 0.1, 1.0)
    return ('', 204)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, threaded=True)
EOF

# 5. Aufnahme mit 15-Minuten-Segmentierung
cat > ~/pi-cam-web/start.sh << 'EOF'
#!/bin/bash

mkdir -p /home/pi/recordings

# Starte segmentierte Aufnahme: alle 900 Sekunden (15 Minuten)
ffmpeg -f v4l2 -framerate 10 -video_size 4608x2592 -i /dev/video0 \
-c:v copy -f segment -segment_time 900 -reset_timestamps 1 \
strftime:/home/pi/recordings/record_%Y-%m-%d_%H-%M.mp4 &

# Starte Web-Oberfläche
/usr/bin/python3 /home/pi/pi-cam-web/app.py
EOF

chmod +x ~/pi-cam-web/start.sh

# 6. systemd-Service für Autostart
cat | sudo tee /etc/systemd/system/pi-camera-web.service << EOF
[Unit]
Description=Pi Kamera Web mit Segmentierung
After=network.target

[Service]
ExecStart=/home/pi/pi-cam-web/start.sh
WorkingDirectory=/home/pi/pi-cam-web
StandardOutput=inherit
StandardError=inherit
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable pi-camera-web.service
sudo systemctl start pi-camera-web.service

# 7. NGINX + Passwortschutz
sudo rm -f /etc/nginx/sites-enabled/default
cat | sudo tee /etc/nginx/sites-available/recordings << EOF
server {
    listen 80;
    server_name _;

    location /recordings {
        auth_basic "Zugang beschränkt";
        auth_basic_user_file /etc/nginx/.htpasswd;
        alias /home/pi/recordings;
        autoindex on;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/recordings /etc/nginx/sites-enabled/recordings
echo "admin:$(openssl passwd -apr1 adminroot)" | sudo tee /etc/nginx/.htpasswd > /dev/null
sudo systemctl restart nginx

# 8. Autolöschung nach 7 Tagen
(crontab -l 2>/dev/null; echo "0 2 * * * find /home/pi/recordings -type f -name '*.mp4' -mtime +7 -delete") | crontab -

echo "=== Installation abgeschlossen ==="
echo "Web-Oberfläche: http://<PI_IP>:8000"
echo "Aufnahmen (Login: admin/adminroot): http://<PI_IP>/recordings"
