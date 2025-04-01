# Ping Pulse
<img width="634" alt="image" src="https://github.com/user-attachments/assets/3e5786f1-2741-4219-9119-bce6e9006b72" />

## 🎯 Description
**Ping Pulse** is a lightweight, intuitive network diagnostic tool tailored for **macOS** users. It provides a clear, real-time visual of your network's health using standard Bash utilities. Through a progressive, layered testing approach, it reflects the actual structure of network connectivity.

Watch as a friendly ghost (👻) journeys through the five layers of your network stack — from your device to the wider internet — pinpointing exactly where issues arise with instant visual feedback.

## ⚙️ How it works
**Ping Pulse** conducts network troubleshooting through a structured five-layer approach, each stage verifying a fundamental aspect of network connectivity. Tests must pass sequentially, as each test depends on the successful completion of the previous step.

### ➟ 🖥️ Local TCP/IP Stack
  * Tests if your computer's internal networking software (TCP/IP stack) is operational by verifying internal loopback connectivity.

    (ping `127.0.0.1`)
    
    * **If failed:** Indicates a fundamental software or OS-level network issue.

### ➟ 🎛️ Network Interface (NIC)
  * Verifies if your network adapter is active and correctly configured by pinging your local IP address.

    * **If failed:** Points to misconfigured adapters, driver issues, or DHCP/IP assignment problems.

### ➟ 📡 Gateway Router
  * Checks connectivity to your local network router by pinging the configured gateway IP. This test also detects router-level ICMP filtering.

    * **If filtered:** Indicates router security settings blocking ICMP (ping), but does not necessarily signify a problem with actual internet connectivity.
    * **If failed (without filtering):** Suggests issues with local router connectivity or misconfiguration.

### ➟ 🌐 Internet Connection
  * Tests external internet connectivity by sequentially pinging reliable public DNS servers,

    (Google DNS: `8.8.8.8`, Cloudflare DNS: `1.1.1.1`, Quad9 DNS: `9.9.9.9`)

    * **If failed:** Indicates issues with router internet access, firewall settings, or an ISP-level outage.

### ➟ 🗺️ DNS Resolution
  * Verifies your system's ability to resolve domain names into IP addresses by attempting to resolve `google.com` through your configured DNS servers.

    * **If failed:** Highlights DNS server unavailability or misconfiguration.
    * **Special Case:** Detects if alternative DNS resolution methods (like browser or OS cache, DNS over HTTPS, or ISP redirects) are compensating for primary DNS issues.

Each stage includes detailed error detection, visual diagnostics, and clear, actionable recommendations for remediation. Animated visual feedback is provided in real-time, clearly illustrating network status progression or interruptions.

## 🌟 Key Features
* 🎬 **Visual Diagnostics:** Animated interface shows network connectivity tests in real-time.
* 🏗️ **Layered Approach:** Troubleshooting follows a logical sequence, mirroring real-world network architectures.
* 🧩 **Ease of Use:** Works with standard bash utilities found on most Unix-like systems.
* 📜 **Detailed Feedback:** Provides specific, actionable advice for fixing detected issues.
* 🚨 **Special Case Detection:** Identifies router ICMP filtering and DNS alternative resolution.

## 📦 Dependencies
* Bash shell
* Standard Unix utilities: `ping`, `route`, `ifconfig`
* Terminal with ANSI color and Unicode support
* (Optional) `dig`/`nslookup` for enhanced DNS diagnostics

## 🛠 Installation
1️⃣ Clone the repository:
```bash
git clone https://github.com/no1annn/ping-pulse.git
```
2️⃣ Make the script executable:
```bash
cd ping-pulse
chmod +x pingpulse.sh
```
3️⃣ Run it!
```bash
./pingpulse.sh
```

## 🌱 Contributing
Contributions to **Ping Pulse** are welcome! Feel free to:
* Report bugs
* Suggest enhancements
* Submit pull requests
