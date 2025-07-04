import tkinter as tk
from tkinter import ttk, messagebox
import subprocess
import os
import webbrowser
from typing import Callable
import logging
import json

class ProxyApp:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.load_config()
        self.setup_window()
        self.setup_styles()
        self.create_widgets()
        self.check_process_status()

    def load_config(self):
        try:
            with open('config.json', 'r') as f:
                self.config = json.load(f)
        except FileNotFoundError:
            self.config = {
                "window": {
                    "title": "Proxy Manager",
                    "width": 400,
                    "height": 350
                },
                "colors": {
                    "bg_color": "#f0f0f0",
                    "fg_color": "#000000",
                    "accent_color": "#4a90d9",
                    "exit_button_color": "#d94a4a"
                },
                "scripts": {
                    "start": "/home/seed/data/scripts/proxy_local_start.sh",
                    "stop": "/home/seed/data/scripts/proxy_local_stop.sh"
                },
                "pid_file": "/tmp/ssh_socks_proxy.pid",
                "ip_info_url": "https://ipinfo.io/json"
            }
            with open('config.json', 'w') as f:
                json.dump(self.config, f, indent=4)

    def setup_window(self):
        self.root.title(self.config["window"]["title"])
        self.root.geometry(f"{self.config['window']['width']}x{self.config['window']['height']}")
        self.root.grid_columnconfigure(0, weight=1)
        self.root.grid_rowconfigure(0, weight=1)

        # Try to set icon using XFCE's method
        try:
            self.root.tk.call('wm', 'iconphoto', self.root._w, tk.PhotoImage(file="/usr/share/pixmaps/proxy-manager.png"))
        except tk.TclError:
            logging.warning("Failed to set application icon.")

    def setup_styles(self):
        self.style = ttk.Style()
        self.style.theme_use("default")  # XFCE typically uses the "default" theme
        
        colors = self.config["colors"]
        
        self.style.configure("TFrame", background=colors["bg_color"])
        self.style.configure("TButton",
                             background=colors["accent_color"],
                             foreground=colors["fg_color"],
                             padding=5)
        self.style.map("TButton",
                       background=[('active', self.adjust_color(colors["accent_color"], -20))])
        self.style.configure("TLabel",
                             background=colors["bg_color"],
                             foreground=colors["fg_color"])
        self.style.configure("Header.TLabel",
                             font=("Sans", 14, "bold"))
        self.style.configure("Status.TLabel",
                             font=("Sans", 11))
        self.style.configure("Exit.TButton",
                             background=colors["exit_button_color"],
                             foreground=colors["fg_color"])
        self.style.map("Exit.TButton",
                       background=[('active', self.adjust_color(colors["exit_button_color"], -20))])

    def adjust_color(self, color, amount):
        r, g, b = int(color[1:3], 16), int(color[3:5], 16), int(color[5:7], 16)
        r = max(0, min(255, r + amount))
        g = max(0, min(255, g + amount))
        b = max(0, min(255, b + amount))
        return f"#{r:02x}{g:02x}{b:02x}"

    def create_widgets(self):
        mainframe = ttk.Frame(self.root, padding="10 10 10 10", style="TFrame")
        mainframe.grid(column=0, row=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        mainframe.grid_columnconfigure(0, weight=1)

        header = ttk.Label(mainframe, text=self.config["window"]["title"], style="Header.TLabel")
        header.grid(column=0, row=0, columnspan=2, pady=(0, 10))

        self.status_frame = ttk.Frame(mainframe, style="TFrame")
        self.status_frame.grid(column=0, row=1, columnspan=2, pady=(0, 10), sticky=(tk.W, tk.E))
        self.status_frame.grid_columnconfigure(0, weight=1)

        self.status_label = ttk.Label(self.status_frame, text="Status: Not running", style="Status.TLabel")
        self.status_label.grid(column=0, row=0, sticky=tk.W)

        self.status_indicator = tk.Canvas(self.status_frame, width=16, height=16, bg=self.config["colors"]["bg_color"], highlightthickness=0)
        self.status_indicator.grid(column=1, row=0, padx=(5, 0), sticky=tk.E)
        self.indicator_oval = self.status_indicator.create_oval(0, 0, 16, 16, fill="red", outline="")

        self.toggle_button = ttk.Button(mainframe, text="Start Proxy", command=self.toggle_process)
        self.toggle_button.grid(column=0, row=2, columnspan=2, pady=(0, 10), sticky=tk.EW)

        ip_info_button = ttk.Button(mainframe, text="Check IP Info", command=self.open_ip_info)
        ip_info_button.grid(column=0, row=3, columnspan=2, pady=(0, 10), sticky=tk.EW)

        exit_button = ttk.Button(mainframe, text="Exit", command=self.root.quit, style="Exit.TButton")
        exit_button.grid(column=0, row=4, columnspan=2, pady=(0, 10), sticky=tk.EW)

    def execute_script(self, script_path: str) -> bool:
        try:
            subprocess.run([script_path], check=True)
            return True
        except subprocess.CalledProcessError as e:
            logging.error(f"Script execution failed: {e}")
            messagebox.showerror("Error", f"Script execution failed: {e}")
            return False

    def start_process(self) -> bool:
        return self.execute_script(self.config["scripts"]["start"])

    def stop_process(self) -> bool:
        return self.execute_script(self.config["scripts"]["stop"])

    def check_process_status(self):
        is_running = os.path.isfile(self.config["pid_file"])
        self.update_ui(is_running)

    def update_ui(self, is_running: bool):
        status_text = "Running" if is_running else "Not running"
        button_text = "Stop Proxy" if is_running else "Start Proxy"
        indicator_color = "#2ecc71" if is_running else "#e74c3c"

        self.status_label.config(text=f"Status: {status_text}")
        self.status_indicator.itemconfig(self.indicator_oval, fill=indicator_color)
        self.toggle_button.config(text=button_text)

    def toggle_process(self):
        action: Callable[[], bool] = self.stop_process if os.path.isfile(self.config["pid_file"]) else self.start_process
        
        if action():
            self.root.after(2000, self.check_process_status)
        else:
            self.check_process_status()

    def open_ip_info(self):
        webbrowser.open(self.config["ip_info_url"])

def main():
    logging.basicConfig(level=logging.INFO)
    root = tk.Tk()
    app = ProxyApp(root)
    root.mainloop()

if __name__ == "__main__":
    main()