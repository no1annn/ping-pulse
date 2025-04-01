# Ping Pulse
<img width="626" alt="image" src="https://github.com/user-attachments/assets/34eb6487-18de-4459-a912-f05005ffdf8c" />

## 🎯 Description
**Ping Pulse** is a lightweight, intuitive network diagnostic tool tailored for **macOS** users. It provides a clear, real-time visual of your network's health using standard Bash utilities. Through a progressive, layered testing approach, it reflects the actual structure of network connectivity.

Watch as a friendly ghost (👻) journeys through the five layers of your network stack — from your device to the wider internet — pinpointing exactly where issues arise with instant visual feedback.

## ⚙️ How it works
**Ping Pulse** conducts network troubleshooting in five structured stages, each dependent on the successful completion of the previous step:
1. 🖥️ **Local TCP/IP Stack:** Tests if your computer's internal networking software is functioning.
2. 🎛️ **Network Interface:** Verifies if your network adapter and drivers are functioning.
3. 📡 **Gateway Router:** Checks connectivity to your local network router.
4. 🌐 **Internet Connection:** Tests connectivity to external internet servers.
5. 🗺️ **DNS Resolution:** Verifies the ability to resolve domain names to IP addresses.

## 🌟 Key Features
* 👀 **Visual Diagnostics:** Animated interface shows network connectivity tests in real-time.
* 🏗️ **Layered Approach:** Troubleshooting follows a logical sequence, mirroring real-world network architectures.
* 🧩 **Ease of Use:** Works with standard bash utilities found on most Unix-like systems.
* 📝 **Detailed Feedback:** Provides specific, actionable advice for fixing detected issues.
* 🚨 **Special Case Detection:** Identifies router ICMP filtering and DNS alternative resolution.

## 📦 Dependencies
* Bash shell
* Standard Unix utilities: `ping`, `route`, `ifconfig`
* Terminal with ANSI color and Unicode support
* (Optional) `dig`/`nslookup` for enhanced DNS diagnostics

## 🛠 Installation
1. Clone the repository:
```bash
git clone https://github.com/nolannn/pingpulse.git
```
2. Make the script executable:
```bash
cd pingpulse
chmod +x pingpulse
```
3. Run it!
```bash
./pingpulse
```

## 🌱 Contributing
Contributions to **Ping Pulse** are welcome! Feel free to:
* Report bugs
* Suggest enhancements
* Submit pull requests
