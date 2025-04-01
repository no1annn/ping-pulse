#!/bin/bash

# Read version from external file
VERSION=$(cat "$(dirname "$0")/VERSION" 2>/dev/null || echo "unknown")

# Version flag support
if [[ "$1" == "--version" || "$1" == "-v" ]]; then
    echo "Ping Pulse v${VERSION}"
    exit 0
fi

# ==================================================================
#                             PING PULSE                            
# ==================================================================
#
# Description:
#   A visual diagnostic tool that tests network connectivity through 
#   five progressive levels:
#   
#          Local stack -> NIC -> Gateway -> Internet -> DNS
#
# Dependencies:
#   - Standard bash utilities (ping, route, ifconfig)
#   - Terminal with ANSI color and Unicode support
#   - dig/nslookup (optional, for enhanced DNS diagnostics)
#
# ==================================================================


# ==================================================================
# Variable Definitions and Configurations···························
# ==================================================================
# This section defines all visual elements, colors, symbols, and 
# messages used throughout the script. Modifying these values will
# change the appearance and text of the diagnostic interface.

# -----------------
# Color Definitions
# -----------------
# This section defines all colors used throughout the script.

# Status Colors
COLOR_SUCCESS_PRIMARY='\033[38;2;67;255;67m'    # Bright green for primary success indicators
COLOR_SUCCESS_ALT='\033[38;2;52;211;153m'       # Softer green for secondary success elements
COLOR_WARNING='\033[38;2;253;224;71m'           # Bright Yellow for warnings and cautions
COLOR_ERROR_PRIMARY='\033[38;2;255;35;61m'      # Deep red for critical errors
COLOR_ERROR_DETAIL='\033[38;2;242;73;92m'       # Lighter red for error details
COLOR_RECOMMENDATION='\033[38;2;255;190;92m'    # Warm orange for recommendations

# UI Elements
COLOR_HEADER='\033[38;2;192;216;255m'           # Soft sky blue for headers
COLOR_HIGHLIGHT='\033[38;2;255;229;204m'        # Warm pastel peach for highlighting important elements
COLOR_PROGRESS_EMPTY='\033[38;2;71;85;105m'     # Subtle gray for unfilled progress indicators
COLOR_PROGRESS_COMPLETE='\033[38;2;255;236;64m' # Bright yellow for completion indicators
COLOR_SPINNER='\033[38;2;112;120;111m'          # Muted gray for spinners
COLOR_TEXT_DETAIL='\033[38;2;255;248;231m'      # Warm white for detailed text

# Indicator Colors
COLOR_INDICATOR_BRIGHT='\033[38;2;138;255;240m' # Bright cyan for indicators
COLOR_INDICATOR_ALERT='\033[38;2;255;133;147m'  # Soft red for alerts

# Accent Colors
COLOR_ACCENT_LAVENDER='\033[38;2;255;208;252m'  # Lavender for accent elements
COLOR_ACCENT_PINK='\033[38;2;222;182;242m'      # Pink for accent elements
COLOR_ACCENT_GREEN='\033[38;2;150;217;141m'     # Green for accent elements
COLOR_ACCENT_BROWN='\033[38;2;157;84;93m'       # Brown for accent frames

# Movement Colors
# (used for the animated elements moving through the network path)
COLOR_MOVING_PRIMARY='\033[38;2;222;253;255m'   # White for primary moving elements
COLOR_MOVING_SECONDARY='\033[38;2;255;189;48m'  # Orange for secondary movement indicators
COLOR_MOVING_TERTIARY='\033[38;2;255;35;61m'    # Red for tertiary movement indicators

# Movement Color Array
# (used when testing different internet targets in sequence)
COLOR_MOVING_ARRAY=(
    "${COLOR_MOVING_PRIMARY}"                   # First target (Google DNS)
    "${COLOR_MOVING_SECONDARY}"                 # Second target (Cloudflare DNS)
    "${COLOR_MOVING_TERTIARY}"                  # Third target (Quad9 DNS)
)

# Formatting Controls
# (reset color code and bold formatting)
NC='\033[0m'                                    # Reset color
BOLD='\033[1m'                                  # Bold text

# ------------------
# Symbol Definitions
# ------------------
# This section defines visual indicators for various network diagnostic states.

# Network Connectivity Failure Indicators
# (appear when specific network connection problems are detected)
FAILURE_SYMBOL_NO_ROUTE="⛔"                    # No route to host
FAILURE_SYMBOL_UNREACHABLE="🚧"                 # Destination host unreachable
FAILURE_SYMBOL_TIMEOUT="⚠️"                     # Request timeout
FAILURE_SYMBOL_UNKNOWN="⁉️"                     # Unknown host (DNS failures)
FAILURE_SYMBOL_SOCKET="🔌"                      # Socket connection issues

# System Configuration Failure Indicators
# (appear during initial network configuration validation)
FAILURE_PRE_CHECK_SYMBOL_NO_IP="⛔"             # No IP address assigned - Network interface lacks IP configuration
FAILURE_PRE_CHECK_SYMBOL_NO_GATEWAY="⛔"        # No gateway configured - Default gateway missing or misconfigured

# Special Case Indicators
# (represent edge cases that aren't failures but require attention)
SPECIAL_SYMBOL_FILTERED="🕸️"                    # Packet filtered - ICMP traffic blocked but underlying network may be functional
SPECIAL_SYMBOL_DNS_ALT="🔄"                     # DNS using alternative resolution - Fallback DNS mechanisms in use


# ==================================================================
# Informational Messages············································
# ==================================================================
# This section defines all text messages displayed during testing.

# ----------------
# General Messages
# ----------------
# Messages used across multiple tests or at the end of diagnostics.

# Special case detection message
# (used for router filtering and DNS alternative resolution)
MSG_SPECIAL_CASE_DETECTED="ⓘ [SPECIAL_CASE_NAME] [SPECIAL_SYMBOL]"

# Final test result messages
MSG_FINAL_SUCCESS="🔋 Your network connection is established and working properly"
MSG_FINAL_FAILURE="🪫 Your network connection is not fully established"
MSG_FINAL_REVIEW="👀 Review the previous failure messages for details"

# --------------------------
# Test 1: Local TCP/IP Stack
# --------------------------
# Messages for testing connectivity to localhost.

# Main test messages (success/failure/recommendation/skip)
MSG_LOCAL_STACK_SUCCESS="The basic networking software (TCP/IP stack) is functioning correctly"
MSG_LOCAL_STACK_FAILURE="The basic networking software is not functioning correctly\n     (Your computer cannot even talk to itself)"
MSG_LOCAL_STACK_RECOMMENDATION="🔬 Check for security software interfering with network connections\n     🔄 Restart your computer to refresh all network components\n     🔄 Reset TCP/IP stack to its default configuration"
MSG_SKIP_AFTER_LOCAL_STACK="Skipping remaining tests due to local TCP/IP stack failure..."

# -------------------------
# Test 2: Network Interface
# -------------------------
# Messages for testing the local network adapter.

# Pre-check: Missing IP address
MSG_NO_IP_FAILURE="Local IP Address not detected\n   ↳ Your network adapter lacks a valid IP configuration"
MSG_NO_IP_RECOMMENDATION="⚙️ Check if DHCP is enabled in your network settings\n     🔬 Verify no IP address conflicts exist on your network\n     🔄 Try disabling and re-enabling the network adapter\n     📨 Consider renewing your DHCP lease to obtain a new IP address"
MSG_SKIP_AFTER_NO_IP="Skipping remaining tests due to missing local IP address..."

# Main test messages (success/failure/recommendation/skip)
MSG_NETWORK_INTERFACE_SUCCESS="The network interface card (NIC) and its driver are functioning correctly"
MSG_NETWORK_INTERFACE_FAILURE="Your system cannot properly communicate with its network hardware"
MSG_NETWORK_INTERFACE_RECOMMENDATION="🔬 Verify the network adapter is physically enabled on your device\n     ⚙️ Update or reinstall drivers from manufacturer's website\n     🔀 Try connecting with a different network cable or wireless network"
MSG_SKIP_AFTER_NETWORK_INTERFACE="Skipping remaining tests due to network interface failure..."

# ----------------------
# Test 3: Gateway Router
# ----------------------
# Messages for testing connectivity to the local gateway router.

# Pre-check: Missing gateway router
MSG_NO_GATEWAY_FAILURE="Gateway Router not detected\n   ↳ Your system doesn't know where to send traffic destined for the internet"
MSG_NO_GATEWAY_RECOMMENDATION="⚙️ Check if your network settings are properly configured and active\n     📶 Check for physical or wireless connection to your router\n     🔌 Verify the cables are connected and your router is powered on\n     🔄 Restart your router and wait for it to fully initialize"
MSG_SKIP_AFTER_NO_GATEWAY="Skipping remaining tests due to missing gateway router..."

# Main test messages (success/failure/recommendation/skip)
MSG_GATEWAY_ROUTER_SUCCESS="You can properly communicate with your router (the door to the internet)"
MSG_GATEWAY_ROUTER_FAILURE="Unable to establish connection with your local network's router"
MSG_GATEWAY_ROUTER_RECOMMENDATION="🚥 Verify your router is powered on with normal status lights\n     📶 Check for network cable connections or Wi-Fi signal strength\n     🔌 Try connecting with another device to rule out a device-specific issue\n     🔄 Restart your router and wait for it to fully initialize"
MSG_SKIP_AFTER_GATEWAY_ROUTER="Skipping remaining tests due to gateway router failure..."

# Special case: Router ICMP filtering
MSG_ROUTER_FILTER_DETECTED="Security Feature Detected"
MSG_ROUTER_BLOCKING_PING="Router or firewall is blocking ping packets for security"
MSG_ICMP_FILTERED="ICMP packets filtered but network is functional"
MSG_CONTINUING_TESTS="Continuing with remaining tests..."

# Special case summary
MSG_ROUTER_FILTERING="🏷️ Router blocks ping but allows regular traffic"
MSG_ROUTER_FILTERING_DETAIL_1="This is often an intentional security feature, not a network problem"
MSG_ROUTER_FILTERING_DETAIL_2="${COLOR_WARNING}[Optional]${NC}${COLOR_ACCENT_PINK} Consider modifying router settings to allow ping requests"

# -----------------------------
# Test 4: Internet Connectivity
# -----------------------------
# Messages for testing connectivity to external internet servers.

# Main test messages (success/failure/recommendation/skip)
MSG_INTERNET_SUCCESS="You can successfully reach the external internet via ${NC}${COLOR_INDICATOR_BRIGHT}[[TARGET_NAME] Server]"
MSG_INTERNET_FAILURE="Your local network is working but cannot reach the public internet"
MSG_INTERNET_RECOMMENDATION="📜 Verify your routing table is properly configured\n     🛡️ Check for firewall software that might be blocking outbound connections\n     📞 Check if your ISP is experiencing an outage or service disruption\n     🔄 Restart your router and wait for it to fully initialize"
MSG_SKIP_AFTER_INTERNET="Skipping remaining tests due to internet connectivity failure..."

# ----------------------
# Test 5: DNS Resolution
# ----------------------
# Messages for testing the ability to resolve domain names to IP addresses.

# Test header
MSG_DNS_CHECK_HEADER="DNS Resolution"
MSG_DNS_CHECK_TARGET="resolving google.com"

# DNS success messages by source
MSG_DNS_ROUTER_SUCCESS="Domain names are resolved through ${NC}${COLOR_ACCENT_GREEN}${BOLD}router-provided${NC}${COLOR_SUCCESS_ALT} DNS server:"
MSG_DNS_VPN_SUCCESS="Domain names are resolved through ${NC}${COLOR_ACCENT_GREEN}${BOLD}VPN-provided${NC}${COLOR_SUCCESS_ALT} DNS server:"
MSG_DNS_MANUAL_SUCCESS="Domain names are resolved through ${NC}${COLOR_ACCENT_GREEN}${BOLD}manually configured${NC}${COLOR_SUCCESS_ALT} DNS server:"
MSG_DNS_OTHER_SUCCESS="Domain names are resolved through detected DNS server:"
MSG_DNS_SUCCESS_RESOLUTION="Successfully resolved: ${NC}${COLOR_INDICATOR_BRIGHT}[DOMAIN] → [IP_ADDRESS]"

# DNS failure messages
MSG_DNS_FAILURE="Unable to resolve domain names through detected DNS server:"
MSG_NO_DNS_DETECTED="No DNS servers could be detected on your system"
MSG_NO_DNS_NO_RESOLUTION="Your system cannot resolve domain names to IP addresses"

# DNS source-specific recommendations
MSG_DNS_ROUTER_RECOMMENDATION="🔄 Restart your router to refresh its DNS settings\n     🔀 Consider configuring public DNS servers (Cloudflare: 1.1.1.1 / Google: 8.8.8.8)\n     📞 Contact your ISP to verify their DNS services are operational"
MSG_DNS_VPN_RECOMMENDATION="🔬 Check your VPN client settings for DNS configuration options\n     🔄 Try disconnecting and reconnecting your VPN\n     ⚙️ Temporarily disable VPN to see if regular DNS works"
MSG_DNS_MANUAL_RECOMMENDATION="⚙️ Verify your configured DNS servers are operational\n     🛡️ Check for firewall or security software blocking DNS queries (port 53)\n     🔀 Try alternative public DNS servers (Cloudflare: 1.1.1.1 / Google: 8.8.8.8)"
MSG_DNS_GENERIC_RECOMMENDATION="⚙️ Verify your configured DNS servers are operational\n     🛡️ Check for firewall or security software blocking DNS queries (port 53)\n     🔀 Consider configuring public DNS servers (Cloudflare: 1.1.1.1 / Google: 8.8.8.8)"
MSG_MANUAL_DNS_CONFIG_RECOMMENDATION="📶 Verify your router is operational and configured to provide DNS service\n     🛡️ Check for firewall or security software blocking DNS queries (port 53)\n     ⚙️ Consider configure DNS servers manually in your network settings\n        (Recommended public DNS servers: Cloudflare: 1.1.1.1 / Google: 8.8.8.8)"

# Special case: DNS alternative resolution
MSG_DNS_ALT_DETECTED="DNS Alternative Resolution Detected"
MSG_DNS_ALT_WARNING="None of the detected DNS servers could be verified to work:"
MSG_DNS_ALT_DETAIL="(OS caching / Browser caching / ISP redirection / DNS over HTTPS)"
MSG_DNS_ALT_WORKS_NO_SERVERS="However, domain names are still being resolved through alternative mechanisms"
MSG_DNS_ALT_SUCCESS="Your internet is functioning properly through an alternate DNS path"
MSG_DNS_ALT_RESOLVED="Successfully resolved (via alternative): [DOMAIN][IP_INFO]"

# Special case summary
MSG_DNS_ALT_FINAL="🏷️ DNS resolution is working through alternative mechanisms"
MSG_DNS_ALT_FINAL_DETAIL_1="Consider configuring reliable DNS servers for better control"
MSG_DNS_ALT_FINAL_DETAIL_2="${COLOR_WARNING}[Suggested]${NC}${COLOR_ACCENT_PINK} Cloudflare: 1.1.1.1 / Google: 8.8.8.8 / Quad9: 9.9.9.9"

# ---------------------
# Spinner Configuration
# ---------------------
# This section defines the animated spinners that appear at the two
# sides of the title and four corners of the main frame during testing,
# providing visual feedback that the script is active and processing.

# Left title spinner (clockwise motion)
TITLE_SPINNER_L=("⠂" "⠃" "⠋" "⠛" "⠻" "⠿" "⠾" "⠶" "⠦" "⠆")

# Right title spinner (counter-clockwise motion)
TITLE_SPINNER_R=("⠐" "⠘" "⠙" "⠛" "⠟" "⠿" "⠷" "⠶" "⠴" "⠰")

# Set initial title spinner index
TITLE_SPINNER_INDEX=0

# Store title position and length
TITLE_ROW=2                 # Row where "PING PULSE" appears
TITLE_START_COL=34          # Column where "PING PULSE" starts
TITLE_END_COL=44            # Column where "PING PULSE" ends
TITLE_SPINNER_ACTIVE=true   # Control flag for title spinners

# ----------------
# Visual Constants
# ----------------
# These constants define the core visual elements of the interface,
# including the frame dimensions, segment lengths, and marker icons.

# Frame components for the main visualization border
FRAME_TOP=" ╭──────────────────────────────────────────────────────────────────────────╮"
FRAME_BOTTOM=" ╰──────────────────────────────────────────────────────────────────────────╯"
FRAME_SIDE="│"

# Horizontal space between frame and internal content
FRAME_PADDING=6

# Progress bar configuration
SEGMENT_LENGTH=10                     # Length of each test segment in the progress bar
icons=("🕳️" "🖥️" "🎛️" "📡" "🌐" "🗺️")   # Icons representing each network level
progress_row=9                        # Row where the progress bar is displayed

# Initialize segment fill array
# (tracks completion status of each segment)
for (( i=0; i<5; i++ )); do
    segment_fill[i]=0
done

# ------------------------
# Animation State Tracking
# ------------------------
# These variables maintain the state of visual elements throughout script execution,
# tracking positions, completion status, and alternative path activations.

# Ghost tracking
# (👻 character that moves along the network path)
LAST_GHOST_X=""                       # Stores the last x-coordinate of the ghost for animation

# Successful test tracking
LAST_SUCCESSFUL_TEST=0                # Tracks the last successfully completed test (0-5)

# Router detour path state
# (when router blocks ICMP but network is functional)
ROUTER_BLOCKED_SEGMENT=-1             # Segment where router blocking was detected (-1 = not detected)
ROUTER_BLOCKED_SYMBOL=""              # Symbol to display for router blocking
ROUTER_DETOUR_TAKEN=false             # Whether the router detour animation has been shown
ROUTER_RIGHT_DOT_LINE_DRAWN=false     # Track if right side of detour path is drawn

# DNS detour path state
# (when DNS servers fail but alternative resolution works)
DNS_BLOCKED_SEGMENT=-1                # Segment where DNS blocking was detected (-1 = not detected)
DNS_BLOCKED_SYMBOL=""                 # Symbol to display for DNS alternative path
DNS_DETOUR_TAKEN=false                # Whether the DNS detour animation has been shown
DNS_RIGHT_DOT_LINE_DRAWN=false        # Track if right side of detour path is drawn


# ==================================================================
# Support Functions·················································
# ==================================================================
# This section contains utility functions used throughout the script
# for formatting, failure detection, and visualization.

# --------------------
# Formatting Functions
# --------------------

# format_test_header():
#   Creates a consistently formatted header for each test
# 
# Parameters:
#   $1 (icon): The emoji icon representing the test
#   $2 (description): Text description of the test
#   $3 (target_info): Command or target being tested
format_test_header() {
    local icon="${1}"
    local description="${2}"
    local target_info="${3}"
    
    # Fixed position for ping command (column 67)
    local target_position=67
    
    # Calculate how many characters already exist
    local desc_length=$(echo -n "Checking ${description}" | wc -m)
    
    # Calculate how many dots are needed to align the ping command
    # (9 accounts for icon, spaces, etc)
    local dots_needed=$((target_position - desc_length - 9))
    
    # Generate the dot string
    local dot_string=""
    for ((i=0; i<dots_needed; i++)); do
        dot_string+="·"
    done
    
    # Output the formatted header
    echo -e "\n${icon} ${COLOR_TEXT_DETAIL}Checking ${description}${COLOR_PROGRESS_EMPTY}${dot_string}${NC}${COLOR_INDICATOR_ALERT}[${target_info}]${NC}"
}

# get_failure_symbol():
#   Returns the appropriate emoji for a specific failure type
#
# Parameters:
#   $1 (failure_type): Type of failure detected (no_route, unreachable, timeout, etc.)
get_failure_symbol() {
    local failure_type="${1}"
    case "${failure_type}" in
        "no_route")    echo "${FAILURE_SYMBOL_NO_ROUTE}" ;;
        "unreachable") echo "${FAILURE_SYMBOL_UNREACHABLE}" ;;
        "timeout")     echo "${FAILURE_SYMBOL_TIMEOUT}" ;;
        "socket")      echo "${FAILURE_SYMBOL_SOCKET}" ;;
        "no_ip")       echo "${FAILURE_PRE_CHECK_SYMBOL_NO_IP}" ;;
        "no_gateway")  echo "${FAILURE_PRE_CHECK_SYMBOL_NO_GATEWAY}" ;;
        *)            echo "${FAILURE_SYMBOL_UNKNOWN}" ;;
    esac
}

# get_special_symbol():
#   Returns the appropriate emoji for a special case
#
# Parameters:
#   $1 (status_type): Type of special status (filtered, dns_alt)
get_special_symbol() {
    local status_type="${1}"
    case "${status_type}" in
        "filtered")    echo "${SPECIAL_SYMBOL_FILTERED}" ;;
        "dns_alt")     echo "${SPECIAL_SYMBOL_DNS_ALT}" ;;
        *)            echo "?" ;;
    esac
}

# --------------------
# Diagnostic Functions
# --------------------

# handle_pre_check_failure():
#   Handles initial configuration failures before regular tests
#
# Parameters:
#   $1 (check_type): Type of pre-check that failed (no_ip, no_gateway)
#   $2 (segment_num): The segment number in the progress bar
#
# Effects:
#   • Displays appropriate failure message and animations
#   • Updates global state variables
handle_pre_check_failure() {
    local check_type="${1}"
    local segment_num="${2}"

    # Variables to show which test is running
    local description=""
    local failure_detail=""
    local recommendation=""
    local icon="🎛️"
    
    case "${check_type}" in
        "no_ip")
            description="Local IP Address"
            failure_detail="${MSG_NO_IP_FAILURE}"
            recommendation="${MSG_NO_IP_RECOMMENDATION}"
            icon="🎛️"
            ;;
        "no_gateway")
            description="Gateway Router"
            failure_detail="${MSG_NO_GATEWAY_FAILURE}"
            recommendation="${MSG_NO_GATEWAY_RECOMMENDATION}"
            icon="📡"
            ;;
    esac
    
    # Display the current test being performed with the custom icon
    format_test_header "${icon}" "${description}" "N/A"
    
    # Animation variables
    local seg_index=${segment_num}
    local offset=0
    local ghost_visible=1
    
    # Set minimum animation duration (in seconds)
    local min_duration=7
    local start_time=$(date +%s)
    
    # Run the animation
    while [ $(( $(date +%s) - start_time )) -lt ${min_duration} ]; do
        draw_progress_bar "${seg_index}" "${offset}"
        if [ ${ghost_visible} -eq 1 ]; then
            ghost_char="👻"
        else
            ghost_char=" "
        fi
        ghost_visible=$(( 1 - ghost_visible ))
        draw_ghost_track "${seg_index}" "0" "${ghost_char}"
        
        # Update spinners
        draw_spinners

        # Animation timing
        sleep 0.17
        
        # Update progress bar position
        offset=$(( offset + 1 ))
        if [ ${offset} -ge ${SEGMENT_LENGTH} ]; then
            offset=0
        fi
    done
    
    # Ensure ghost is visible at the end of animation
    tput sc
    tput cup $(( progress_row - 1 )) $(( LAST_GHOST_X + FRAME_PADDING ))
    echo -ne "👻"
    tput rc
    
    # Show the failure
    segment_fill[seg_index]=0
    local failure_symbol=$(get_failure_symbol "${check_type}")
    draw_failure_segment "${seg_index}" "${failure_symbol}"
    
    # Output failure message
    echo -e " ${COLOR_ERROR_PRIMARY}✘ ${BOLD}Failed ${failure_symbol}${NC}"
    echo -e "   ${COLOR_ERROR_DETAIL}↳ ${failure_detail}${NC}"
    
    sleep 0.5

    # Display recommendations in a consistent format
    echo -e "   ${COLOR_RECOMMENDATION}${BOLD}↳ Recommended Actions:${NC}"
    echo -e "     ${COLOR_RECOMMENDATION}${recommendation}${NC}"

    # Additional messaging based on check type
    case "${check_type}" in
        "no_ip")
            sleep 0.5
            echo -e "\n${COLOR_WARNING}${BOLD}${MSG_SKIP_AFTER_NO_IP}${NC}"
            stop_spinners
            sleep 0.5
            echo -e "\n${COLOR_HIGHLIGHT}${BOLD}[${NC}${COLOR_SUCCESS_PRIMARY}${BOLD}2${NC}${COLOR_HIGHLIGHT}${BOLD}/5] Checks completed at ⏱️[$(date '+%Y-%m-%d %H:%M:%S')]${NC}"
            ;;
        "no_gateway")
            sleep 0.5
            echo -e "\n${COLOR_WARNING}${BOLD}${MSG_SKIP_AFTER_NO_GATEWAY}${NC}"
            stop_spinners
            sleep 0.5
            echo -e "\n${COLOR_HIGHLIGHT}${BOLD}[${NC}${COLOR_SUCCESS_PRIMARY}${BOLD}3${NC}${COLOR_HIGHLIGHT}${BOLD}/5] Checks completed at ⏱️[$(date '+%Y-%m-%d %H:%M:%S')]${NC}"
            ;;
    esac
}

# get_primary_failure_type():
#   Analyzes ping output to determine the type of failure
#
# Parameters:
#   $1 (ping_output): The complete output from a ping command
get_primary_failure_type() {
    local ping_output="${1}"

    # Match any message indicating routing-related issues
    if echo "${ping_output}" | grep -Ei "(route|routing|no[[:space:]]+route|route[[:space:]]+not[[:space:]]+found|no[[:space:]]+routing[[:space:]]+table|network.*unreachable|host.*unreachable|gateway[[:space:]]+failure|routing[[:space:]]+failed|network[[:space:]]+down|host[[:space:]]+down)"; then
        echo "no_route"
        return
    fi

    # Match any message indicating destination unreachability issues
    if echo "${ping_output}" | grep -Ei "(destination|dest[[:space:]]+unreachable|destination[[:space:]]+not[[:space:]]+reachable|icmp.*unreachable|host[[:space:]]+unreachable|network[[:space:]]+unreachable)"; then
        echo "unreachable"
        return
    fi
    
    # Timeout issues
    # Match any message indicating timeout or packet loss issues
    if echo "${ping_output}" | grep -Ei "(timeout|request.*timeout|timed[[:space:]]+out|[0-9]+%[[:space:]]+packet[[:space:]]+loss|no[[:space:]]+response|0[[:space:]]+packets[[:space:]]+received|network[[:space:]]+timeout|connection[[:space:]]+timeout|icmp[[:space:]]+timeout)"; then
        echo "timeout"
        return
    fi

    # Socket-related issues
    # Match any message indicating socket-related issues
    if echo "${ping_output}" | grep -Ei "(socket|connect|connection|connected|fail|error|refused|denied|not[[:space:]]+connected|unable[[:space:]]+to[[:space:]]+connect)"; then
        echo "socket"
        return
    fi
    
    # DNS resolution issues
    # Match any message indicating DNS-related issues
    if echo "${ping_output}" | grep -Ei "(resolve|unknown[[:space:]]+host|name[[:space:]]+or[[:space:]]+service[[:space:]]+not[[:space:]]+known|dns.*(fail|error|timeout)|could[[:space:]]+not[[:space:]]+resolve|host[[:space:]]+not[[:space:]]+found|lookup[[:space:]]+failed|temporary[[:space:]]+failure[[:space:]]+in[[:space:]]+name[[:space:]]+resolution)"; then
        echo "unknown"
        return
    fi
    
    # If no patterns match, return unknown
    echo "unknown"
}


# ==================================================================
# Visualization Functions···········································
# ==================================================================
# This section contains functions that handle the terminal-based 
# user interface, including drawing the progress bar, animations,
# and visual indicators for test results.

# ------------------------
# Base Interface Functions
# ------------------------

# Hide the cursor while the script runs (restored at the end)
tput civis

# print_banner():
#   Creates an animated title banner with gradient borders
print_banner() {
    clear
    echo -e "${BOLD}"
    
    # Print top gradient line with animation (left to right)
    local length=78             # Width of the gradient line
    local r1=34 g1=211 b1=238   # Starting RGB color
    local r2=157 g2=84 b2=93    # Ending RGB color
    
    echo ""
    
    # Move cursor up to the empty line for drawing the animation
    tput cuu1
    
    # Create and display the gradient by printing dots with interpolated colors
    for ((i=0; i<length; i++)); do
        # Calculate the color for current position using linear interpolation
        # Ratio goes from 0% (start) to 100% (end) based on position
        local ratio=$(( i * 100 / (length - 1) ))

        # Apply the ratio to each RGB component
        local r=$(( r1 + (r2 - r1) * ratio / 100 ))
        local g=$(( g1 + (g2 - g1) * ratio / 100 ))
        local b=$(( b1 + (b2 - b1) * ratio / 100 ))
        
        # Print a dot with the calculated color
        echo -ne "\033[38;2;${r};${g};${b}m·\033[0m"
        
        # Small delay creates the animated effect of dots appearing sequentially
        sleep 0.0055
    done

    echo ""
    
    # Print the main title with consistent cyan color and bold formatting
    echo -e "${COLOR_HEADER}${BOLD}                                  PING PULSE                                  ${NC}"
    echo ""
    
    # Move cursor up to the empty line for drawing the animation
    tput cuu1
    
    # Pre-calculate all colors for the bottom gradient
    declare -a dot_colors
    for ((i=0; i<length; i++)); do
        # For bottom gradient, reverse the ratio direction (100% to 0%)
        local ratio=$(( (length - 1 - i) * 100 / (length - 1) ))

        # Calculate RGB components with the reversed ratio
        local r=$(( r1 + (r2 - r1) * ratio / 100 ))
        local g=$(( g1 + (g2 - g1) * ratio / 100 ))
        local b=$(( b1 + (b2 - b1) * ratio / 100 ))
        
        # Store the color code in the array
        dot_colors[i]="\033[38;2;${r};${g};${b}m·\033[0m"
    done
    
    # Animate from right to left using the stored colors
    for ((i=length-1; i>=0; i--)); do
        # Position cursor at specified column (i) on current line
        tput hpa $((i))
        
        # Print the dot with pre-calculated color
        echo -ne "${dot_colors[i]}"
        
        # Faster animation speed for bottom gradient
        sleep 0.0005
    done

    echo ""
    echo ""

    # Reset text formatting
    echo -e "${NC}"
    sleep 0.5

    # Enable the animated spinners that will appear on both sides of title
    TITLE_SPINNER_ACTIVE=true
    
    # Draw the initial spinner characters
    # Save cursor
    tput sc

    # Position and draw the left spinner
    tput cup "${TITLE_ROW}" "$((TITLE_START_COL - 2))"
    echo -ne "${COLOR_SPINNER}${TITLE_SPINNER_L[0]}${NC}"

    # Position and draw the right spinner
    tput cup "${TITLE_ROW}" "$((TITLE_END_COL + 1))"
    echo -ne "${COLOR_SPINNER}${TITLE_SPINNER_R[0]}${NC}"

    # Restore cursor
    tput rc
}

# draw_frame():
#   Creates the main UI frame for the diagnostics
draw_frame() {
    tput cup 5 0
    echo -e "${COLOR_ACCENT_BROWN}${FRAME_TOP}${NC}"

    for row in {6..12}; do
        tput cup ${row} 0
        echo -ne "${COLOR_ACCENT_BROWN} ${FRAME_SIDE}${NC}"
        printf "%${FRAME_PADDING}s" ""
        tput cup ${row} $((${#FRAME_TOP} - 1))
        echo -ne "${COLOR_ACCENT_BROWN}${FRAME_SIDE}${NC}"
    done

    tput cup 12 0
    echo -e "${COLOR_ACCENT_BROWN}${FRAME_BOTTOM}${NC}"
    
    # Start spinners
    TITLE_SPINNER_ACTIVE=true
    TITLE_SPINNER_INDEX=0
    draw_spinners
}

# ----------------------
# Progress Visualization
# ----------------------

# draw_progress_bar():
#   Draws the main progress bar showing test status
#
# Parameters:
#   $1 (current_segment): Which segment is currently being tested (0-4)
#   $2 (offset): Position within the current segment (0-SEGMENT_LENGTH)
#   $3 (moving_color): Optional color for the moving indicator
#
# Effects: 
#   • Updates the progress bar display on the terminal
#   • Shows completed segments, active segment, and inactive segments
#   • Displays appropriate indicators for failed or blocked segments
draw_progress_bar() {
    local current_segment=${1}
    local offset=${2}
    local moving_color=${3:-"${COLOR_MOVING_PRIMARY}"}
    local bar=""

    for (( i=0; i<5; i++ )); do
        bar+="${icons[i]}${NC}"
        local seg=""
        if [ "${i}" -eq "${current_segment}" ]; then
            # Handle active segment
            for (( j=0; j<segment_fill[i]; j++ )); do
                seg+="${COLOR_HIGHLIGHT}≖${NC}"
            done
            if [ ${offset} -ge ${segment_fill[i]} ] && [ ${offset} -lt ${SEGMENT_LENGTH} ]; then
                for (( j=segment_fill[i]; j<offset; j++ )); do
                    seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
                done
                seg+="${moving_color}•${NC}"
                for (( j=offset+1; j<SEGMENT_LENGTH; j++ )); do
                    seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
                done
            else
                for (( j=segment_fill[i]; j<SEGMENT_LENGTH; j++ )); do
                    seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
                done
            fi
        elif [ "${i}" -eq "${ROUTER_BLOCKED_SEGMENT}" ]; then
            # Draw Gateway Router blocked segment with appropriate symbol
            local middle_pos=$(( SEGMENT_LENGTH / 2 - 1 ))
            for (( j=0; j<middle_pos; j++ )); do
                seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
            done
            seg+="${COLOR_ERROR_PRIMARY}${ROUTER_BLOCKED_SYMBOL}${NC}"
            for (( j=middle_pos+2; j<SEGMENT_LENGTH; j++ )); do
                seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
            done
        elif [ "${i}" -eq "${DNS_BLOCKED_SEGMENT}" ]; then
            # Draw DNS blocked segment with appropriate symbol
            local middle_pos=$(( SEGMENT_LENGTH / 2 - 1 ))
            for (( j=0; j<middle_pos; j++ )); do
                seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
            done
            seg+="${COLOR_ERROR_PRIMARY}${DNS_BLOCKED_SYMBOL}${NC}"
            for (( j=middle_pos+2; j<SEGMENT_LENGTH; j++ )); do
                seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
            done
        else
            for (( j=0; j<segment_fill[i]; j++ )); do
                seg+="${COLOR_HIGHLIGHT}≖${NC}"
            done
            for (( j=segment_fill[i]; j<SEGMENT_LENGTH; j++ )); do
                seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
            done
        fi
        bar+="${seg}"
    done
    bar+="${icons[5]}${NC}"

    tput sc
    tput cup ${progress_row} 0
    echo -ne "${COLOR_ACCENT_BROWN} ${FRAME_SIDE}${NC}"
    printf "%${FRAME_PADDING}s" ""
    echo -ne "${bar}"
    tput cup ${progress_row} $((${#FRAME_TOP} - 1))
    echo -ne "${COLOR_ACCENT_BROWN}${FRAME_SIDE}${NC}"
    tput rc

    # Maintain detour paths if they exist
    if [ "${ROUTER_DETOUR_TAKEN}" = true ]; then
        redraw_router_detour_path
    fi
    
    if [ "${DNS_DETOUR_TAKEN}" = true ]; then
        redraw_dns_detour_path
    fi
}

# draw_ghost_track():
#   Draws the moving ghost character (👻) above the progress bar
#
# Parameters:
#   $1 (current_segment): Which segment the ghost is in (0-4)
#   $2 (offset): Position within the segment (0-SEGMENT_LENGTH)
#   $3 (ghost_char): The character to display (usually 👻 or space)
#
# Effects: 
#   • Updates the ghost position on the terminal
#   • Clears the previous ghost position
#   • Stores the current ghost position for next update
draw_ghost_track() {
    local current_segment=${1}
    local offset=${2}
    local ghost_char=${3}
    local -a marker_positions=(2 14 26 38 50 62)

    local x=0
    if [ ${offset} -eq ${SEGMENT_LENGTH} ]; then
        x=${marker_positions[$((current_segment + 1))]}
    else
        x=$(( ${marker_positions[${current_segment}]} + offset ))
    fi

    # Save cursor
    tput sc

    # Instead of clearing the entire row, only clear the ghost's previous position
    if [ -n "${LAST_GHOST_X}" ]; then
        tput cup $(( progress_row - 1 )) $((LAST_GHOST_X + FRAME_PADDING))
        echo -n " "  # Clear only the previous ghost position
    fi

    # Calculate new ghost position
    local ghost_col=$((x + FRAME_PADDING))
    LAST_GHOST_X=${x}  # Store current position for next update
    
    # Move to new position and draw ghost
    tput cup $(( progress_row - 1 )) ${ghost_col}
    echo -ne "${ghost_char}"

    # Restore cursor
    tput rc
}

# draw_failure_segment():
#   Draws a segment with failure indication
#
# Parameters:
#   $1 (seg_index): Which segment failed (0-4)
#   $2 (failure_symbol): The emoji symbol to display for the failure
#
# Effects: 
#   • Updates the progress bar to show the failure symbol
#   • Maintains any detour paths that exist
draw_failure_segment() {
    local seg_index=${1}
    local failure_symbol=${2}
    local middle_pos=$(( SEGMENT_LENGTH / 2 - 1 ))
    
    tput sc
    tput cup ${progress_row} 0
    echo -ne "${COLOR_ACCENT_BROWN} ${FRAME_SIDE}${NC}"
    printf "%${FRAME_PADDING}s" ""
    
    local bar=""
    for (( i=0; i<5; i++ )); do
        bar+="${icons[i]}${NC}"
        local seg=""
        if [ "${i}" -eq "${seg_index}" ]; then
            # Draw current segment with the failure symbol
            for (( j=0; j<middle_pos; j++ )); do
                seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
            done
            seg+="${COLOR_ERROR_PRIMARY}${failure_symbol}${NC}"
            for (( j=middle_pos+2; j<SEGMENT_LENGTH; j++ )); do
                seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
            done
        elif [ "${i}" -eq "${ROUTER_BLOCKED_SEGMENT}" ]; then
            # Draw Gateway Router blocked segment with appropriate symbol
            local mid_pos=$(( SEGMENT_LENGTH / 2 - 1 ))
            for (( j=0; j<mid_pos; j++ )); do
                seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
            done
            seg+="${COLOR_ERROR_PRIMARY}${ROUTER_BLOCKED_SYMBOL}${NC}"
            for (( j=mid_pos+2; j<SEGMENT_LENGTH; j++ )); do
                seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
            done
        elif [ "${i}" -eq "${DNS_BLOCKED_SEGMENT}" ]; then
            # Draw DNS blocked segment with appropriate symbol
            local mid_pos=$(( SEGMENT_LENGTH / 2 - 1 ))
            for (( j=0; j<mid_pos; j++ )); do
                seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
            done
            seg+="${COLOR_ERROR_PRIMARY}${DNS_BLOCKED_SYMBOL}${NC}"
            for (( j=mid_pos+2; j<SEGMENT_LENGTH; j++ )); do
                seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
            done
        else
            for (( j=0; j<segment_fill[i]; j++ )); do
                seg+="${COLOR_HIGHLIGHT}≖${NC}"
            done
            for (( j=segment_fill[i]; j<SEGMENT_LENGTH; j++ )); do
                seg+="${COLOR_PROGRESS_EMPTY}.${NC}"
            done
        fi
        bar+="${seg}"
    done
    bar+="${icons[5]}${NC}"
    
    echo -ne "${bar}"
    tput cup ${progress_row} $((${#FRAME_TOP} - 1))
    echo -ne "${COLOR_ACCENT_BROWN}${FRAME_SIDE}${NC}"
    tput rc

    # Maintain detour paths if they exist
    if [ "${ROUTER_DETOUR_TAKEN}" = true ]; then
        redraw_router_detour_path
    fi
    
    if [ "${DNS_DETOUR_TAKEN}" = true ]; then
        redraw_dns_detour_path
    fi
}

# animate_segment_completion():
#   Handles animation when test segment completes
#
# Parameters:
#   $1 (seg_index): Which segment is completing (0-4)
#   $2 (success): Whether the test was successful (true/false)
#   $3 (failure_type): If failed, what type of failure
#   $4 (is_detour): Optional, whether this is part of a detour animation
#
# Returns:
#   0 - If the segment completed successfully
#   1 - If the segment failed
#
# Effects: 
#   • Fills the segment with completion indicators (≖) for success
#   • Shows appropriate failure symbol for failures
#   • Moves ghost to the next segment on success
animate_segment_completion() {
    local seg_index=${1}
    local success=${2}
    local failure_type=${3}
    local is_detour=${4:-false}

    if [ "${is_detour}" = true ]; then
        return 0
    fi
    
    if [ "${success}" = true ]; then
        # Check if the Internet Connectivity segment starts after a detour
        if [ "${seg_index}" -eq 3 ] && [ "${ROUTER_DETOUR_TAKEN}" = true ]; then
            ROUTER_RIGHT_DOT_LINE_DRAWN=true
        fi

        for (( fill=segment_fill[seg_index]; fill<=SEGMENT_LENGTH; fill++ )); do
            segment_fill[seg_index]=${fill}
            draw_progress_bar -1 0
            draw_ghost_track "${seg_index}" "${fill}" "👻"

            # Update spinners
            draw_spinners

            # Adjust sleep time based on whether the ghost is in post-detour
            # (since all the extra drawing operations add small delays)
            if [ "${ROUTER_DETOUR_TAKEN}" = true ] || [ "${DNS_DETOUR_TAKEN}" = true ]; then
                :
            else
                sleep 0.1
            fi
        done
        if [ ${seg_index} -lt 4 ]; then
            draw_ghost_track $(( seg_index + 1 )) 0 "👻"
            draw_spinners   # Update spinners
        fi
        return 0
    else
        # Get the appropriate failure symbol
        local failure_symbol=$(get_failure_symbol "${failure_type}")
        segment_fill[seg_index]=0
        draw_failure_segment "${seg_index}" "${failure_symbol}"
        draw_ghost_track "${seg_index}" 0 "👻"
        draw_spinners       # Update spinners
        return 1
    fi
}

# -------------------------
# Detour Path Visualization
# -------------------------

# draw_router_detour_path():
#   Draws the detour path when router ICMP filtering is detected
#
# Parameters:
#   $1 (step): Current animation step (1-16)
#
# Effects: 
#   • Draws a step-by-step animation of the ghost taking a detour path
#   • Creates a path of dots, corners, and connecting lines
#   • Shows the ghost moving along the path
draw_router_detour_path() {
    local step=${1}
    local base_x=32                     # Position (x-coordinate) of icon (🎛️)
    local base_y=${progress_row}        # Position (y-coordinate) of icon (🎛️)
    local ghost_x ghost_y
    
    case ${step} in
        1)
            # Step 1: Ghost appears at (x, y-1)
            ghost_x=${base_x}
            ghost_y=$(( base_y - 1 ))
            tput sc
            tput cup ${ghost_y} ${ghost_x}
            echo -ne "👻"
            tput rc
            ;;
        2)
            # Step 2: Ghost moves to (x, y+2), leaving ":" at (x, y+1)
            tput sc
            tput cup $(( base_y - 1 )) ${base_x}
            echo -ne "${COLOR_HIGHLIGHT}:${NC}"
            tput rc
            ghost_x=${base_x}
            ghost_y=$(( base_y - 2 ))
            tput sc
            tput cup ${ghost_y} ${ghost_x}
            echo -ne "👻"
            tput rc
            ;;
        3)
            # Step 3: Ghost moves to (x+1, y-2), leaving "╭" at (x, y-2)
            tput sc
            tput cup $(( base_y - 2 )) ${base_x}
            echo -ne "${COLOR_HIGHLIGHT}╭${NC}"
            tput rc
            # Draw ghost in new position
            ghost_x=$(( base_x + 1 ))
            ghost_y=$(( base_y - 2 ))
            tput sc
            tput cup ${ghost_y} ${ghost_x}
            echo -ne "👻"
            tput rc
            ;;
        4|5|6|7|8|9|10|11|12|13|14)
            # Steps 4-14: Moving right, leaving "·" along the way
            local prev_x=$(( base_x + step - 3 ))
            ghost_x=$(( base_x + step - 2 ))
            ghost_y=$(( base_y - 2 ))
            # Draw horizontal line element where ghost just left
            tput sc
            tput cup ${ghost_y} ${prev_x}
            echo -ne "${COLOR_HIGHLIGHT}·${NC}"
            tput rc
            # Draw ghost in new position
            tput sc
            tput cup ${ghost_y} ${ghost_x}
            echo -ne "👻"
            tput rc
            ;;
        15)
            # Step 15: Ghost moves to (x+12, y-1), leaving "╮" at (x+12, y-2)
            # Draw the last horizontal segment
            tput sc
            tput cup $(( base_y - 2 )) $(( base_x + 12 ))
            echo -ne "${COLOR_HIGHLIGHT}╮${NC}"
            tput rc
            # Draw ghost in new position
            ghost_x=$(( base_x + 12 ))
            ghost_y=$(( base_y - 1 ))
            tput sc
            tput cup ${ghost_y} ${ghost_x}
            echo -ne "👻"
            tput rc
            ;;
        16)
            # Step 16: Ghost remains in final position (x+12, y-1)
            ghost_x=$(( base_x + 12 ))
            ghost_y=$(( base_y - 1 ))
            tput sc
            tput cup ${ghost_y} ${ghost_x}
            echo -ne "👻"
            tput rc
            ;;
    esac
}

# redraw_router_detour_path():
#   Redraws the complete router detour path
#
# Note:
#   This function is called whenever the progress bar is redrawn to ensure
#   the router detour path remains visible. It draws all elements of the path
#   without animation.
#
# Effects: 
#   • Redraws the complete router detour path
#   • Ensures the detour path remains visible during other updates
redraw_router_detour_path() {
    local base_x=32                     # Position (x-coordinate) of icon (🎛️)
    local base_y=${progress_row}        # Position (y-coordinate) of icon (🎛️)

    # Save cursor
    tput sc
    
    # Left dot line
    tput cup $(( base_y - 1 )) ${base_x}
    echo -ne "${COLOR_HIGHLIGHT}:${NC}"
    
    # Right dot line (only draw if the ghost has moved on)
    if [ "${ROUTER_RIGHT_DOT_LINE_DRAWN}" = true ]; then
        tput cup $(( base_y - 1 )) $(( base_x + 12 ))
        echo -ne "${COLOR_HIGHLIGHT}:${NC}"
    fi
    
    # Upper path
    tput cup $(( base_y - 2 )) ${base_x}
    echo -ne "${COLOR_HIGHLIGHT}╭${NC}"
    for ((i=1; i<=11; i++)); do
        tput cup $(( base_y - 2 )) $(( base_x + i ))
        echo -ne "${COLOR_HIGHLIGHT}·${NC}"
    done
    tput cup $(( base_y - 2 )) $(( base_x + 12 ))
    echo -ne "${COLOR_HIGHLIGHT}╮${NC}"
    
    # Restore cursor
    tput rc
}

# draw_dns_detour_path():
#   Draws the detour path when DNS alternative resolution is detected
#
# Parameters:
#   $1 (step): Current animation step (1-16)
#
# Effects: 
#   • Draws a step-by-step animation of the ghost taking a DNS detour path
#   • Creates a path of dots, corners, and connecting lines
#   • Shows the ghost moving along the path
draw_dns_detour_path() {
    local step=${1}
    local base_x=56                     # Position (x-coordinate) of icon (🌐)
    local base_y=${progress_row}        # Position (y-coordinate) of icon (🌐)
    local ghost_x ghost_y
    
    case ${step} in
        1)
            # Step 1: Ghost appears at (x, y-1)
            ghost_x=${base_x}
            ghost_y=$(( base_y - 1 ))
            tput sc
            tput cup ${ghost_y} ${ghost_x}
            echo -ne "👻"
            tput rc
            ;;
        2)
            # Step 2: Ghost moves to (x, y-2), leaving ":" at (x, y-1)
            tput sc
            tput cup $(( base_y - 1 )) ${base_x}
            echo -ne "${COLOR_HIGHLIGHT}:${NC}"
            tput rc
            ghost_x=${base_x}
            ghost_y=$(( base_y - 2 ))
            tput sc
            tput cup ${ghost_y} ${ghost_x}
            echo -ne "👻"
            tput rc
            ;;
        3)
            # Step 3: Ghost moves to (x+1, y-2), leaving "╭" at (x, y-2)
            tput sc
            tput cup $(( base_y - 2 )) ${base_x}
            echo -ne "${COLOR_HIGHLIGHT}╭${NC}"
            tput rc
            # Draw ghost in new position
            ghost_x=$(( base_x + 1 ))
            ghost_y=$(( base_y - 2 ))
            tput sc
            tput cup ${ghost_y} ${ghost_x}
            echo -ne "👻"
            tput rc
            ;;
        4|5|6|7|8|9|10|11|12|13|14)
            # Steps 4-14: Moving right, leaving "·" along the way
            local prev_x=$(( base_x + step - 3 ))
            ghost_x=$(( base_x + step - 2 ))
            ghost_y=$(( base_y - 2 ))
            # Draw horizontal line element where ghost just left
            tput sc
            tput cup ${ghost_y} ${prev_x}
            echo -ne "${COLOR_HIGHLIGHT}·${NC}"
            tput rc
            # Draw ghost in new position
            tput sc
            tput cup ${ghost_y} ${ghost_x}
            echo -ne "👻"
            tput rc
            ;;
        15)
            # Step 15: Ghost moves to (x+12, y-1), leaving "╮" at (x+12, y-2)
            # Draw the last horizontal segment
            tput sc
            tput cup $(( base_y - 2 )) $(( base_x + 12 ))
            echo -ne "${COLOR_HIGHLIGHT}╮${NC}"
            tput rc
            # Draw ghost in new position
            ghost_x=$(( base_x + 12 ))
            ghost_y=$(( base_y - 1 ))
            tput sc
            tput cup ${ghost_y} ${ghost_x}
            echo -ne "👻"
            tput rc
            ;;
        16)
            # Step 16: Ghost remains in final position (x+12, y-1)
            ghost_x=$(( base_x + 12 ))
            ghost_y=$(( base_y - 1 ))
            tput sc
            tput cup ${ghost_y} ${ghost_x}
            echo -ne "👻"
            tput rc
            ;;
    esac
}

# redraw_dns_detour_path():
#   Redraws the complete DNS detour path
#
# Note:
#   This function is called whenever the progress bar is redrawn to ensure
#   the DNS detour path remains visible. It draws all elements of the path
#   without animation.
#
# Effects: 
#   • Redraws the complete DNS detour path
#   • Ensures the detour path remains visible during other updates
redraw_dns_detour_path() {
    local base_x=56                     # Position (x-coordinate) of icon (🌐)
    local base_y=${progress_row}        # Position (y-coordinate) of icon (🌐)

    # Save cursor
    tput sc
    
    # Left dot line
    tput cup $(( base_y - 1 )) ${base_x}
    echo -ne "${COLOR_HIGHLIGHT}:${NC}"
    
    # Right dot line (only draw if the ghost has moved on)
    if [ "${DNS_RIGHT_DOT_LINE_DRAWN}" = true ]; then
        tput cup $(( base_y - 1 )) $(( base_x + 12 ))
        echo -ne "${COLOR_HIGHLIGHT}:${NC}"
    fi
    
    # Upper path
    tput cup $(( base_y - 2 )) ${base_x}
    echo -ne "${COLOR_HIGHLIGHT}╭${NC}"
    for ((i=1; i<=11; i++)); do
        tput cup $(( base_y - 2 )) $(( base_x + i ))
        echo -ne "${COLOR_HIGHLIGHT}·${NC}"
    done
    tput cup $(( base_y - 2 )) $(( base_x + 12 ))
    echo -ne "${COLOR_HIGHLIGHT}╮${NC}"
    
    # Restore cursor
    tput rc
}

# -----------------
# Animation Control
# -----------------

# draw_spinners():
#   Draws the animated spinners around the title
#
# Effects: 
#   • Updates and redraws the spinners that appear at the sides of the
#     "PING PULSE" title
#   • Provides visual feedback that the script is active and running
draw_spinners() {
    if [ "${TITLE_SPINNER_ACTIVE}" = false ]; then
        return
    fi
    
    # Increment the title spinner index
    TITLE_SPINNER_INDEX=$(( (TITLE_SPINNER_INDEX + 1) % ${#TITLE_SPINNER_L[@]} ))

    # Save cursor
    tput sc
    
    # Draw title spinners
    if [ "${TITLE_SPINNER_ACTIVE}" = true ]; then
        # Draw left title spinner
        tput cup "${TITLE_ROW}" "$((TITLE_START_COL - 2))"
        echo -ne "${COLOR_SPINNER}${TITLE_SPINNER_L[${TITLE_SPINNER_INDEX}]}${NC}"
        
        # Draw right title spinner
        tput cup "${TITLE_ROW}" "$((TITLE_END_COL + 1))"
        echo -ne "${COLOR_SPINNER}${TITLE_SPINNER_R[${TITLE_SPINNER_INDEX}]}${NC}"
    fi

    # Restore cursor
    tput rc
}

# stop_spinners():
#   Stops the spinner animation
stop_spinners() {
    TITLE_SPINNER_ACTIVE=false
}


# ==================================================================
# Main Test Function················································
# ==================================================================
# Core network testing function that performs individual connectivity
# tests with visual progress animation and detailed result reporting.

# run_ping_test_animated():
#   Runs a ping test with animated progress
#
# Parameters:
#   $1 (level): Test level (1-5) determining which segment to animate
#   $2 (target): IP address or hostname to ping
#   $3 (description): Human-readable description of the test
#   $4 (success_detail): Message to display on successful test
#   $5 (failure_detail): Message to display on test failure
#   $6 (recommendation): Recommended actions on test failure
#   $7 (icon): Optional icon to display next to test description
#
# Returns:
#   0 - If ping succeeds
#   1 - If ping fails
#
# Effects: 
#   • Displays test header and animates progress
#   • Shows success/failure message and recommendations
#   • Updates global state variables like LAST_SUCCESSFUL_TEST
#   • May initiate detour animations for special cases
run_ping_test_animated() {
    local level=${1}            # Test level (1-5)
    local target=${2}           # Target IP/hostname to ping
    local description=${3}      # Human-readable test description
    local success_detail=${4}   # Message to show on success
    local failure_detail=${5}   # Message to show on failure
    local recommendation=${6}   # Recommended Actions on failure
    local icon=${7:-"🪬"}       # Custom icon for the test (defaults to 🪬 if not provided)

    # Display the current test being performed with the custom icon using the helper function
    format_test_header "${icon}" "${description}" "ping ${target}"

    # Create temporary file for ping output and run ping in background
    local temp_file=$(mktemp)
    ping -c 5 "${target}" > "${temp_file}" 2>&1 &
    local ping_pid=$!

    # Calculate which segment is being tested (0-based index)
    local seg_index=$(( level - 1 ))
    local offset=0
    local ghost_visible=1

    # Set minimum animation duration (in seconds)
    local min_duration=7
    local start_time=$(date +%s)
    local ping_completed=false

    # Animate progress for at least the minimum duration
    while [ $(( $(date +%s) - start_time )) -lt ${min_duration} ] || ! ${ping_completed}; do
        # Check if ping has completed
        if ! kill -0 "${ping_pid}" 2>/dev/null && ! ${ping_completed}; then
            ping_completed=true
            wait "${ping_pid}"
            ping_result=$?
            ping_output=$(cat "${temp_file}")
        fi

        # Continue animation
        draw_progress_bar "${seg_index}" "${offset}"
        if [ ${ghost_visible} -eq 1 ]; then
            ghost_char="👻"
        else
            ghost_char=" "
        fi
        ghost_visible=$(( 1 - ghost_visible ))
        draw_ghost_track "${seg_index}" "0" "${ghost_char}"

        # Update spinners
        draw_spinners

        # Adjust animation speed based on whether the ghost is in post-detour
        if [ "${ROUTER_DETOUR_TAKEN}" = true ] || [ "${DNS_DETOUR_TAKEN}" = true ]; then
            sleep 0.05  # Faster after detour to keep things snappy
        else
            sleep 0.17  # Normal speed before detour
        fi

        # Update progress bar position
        offset=$(( offset + 1 ))
        if [ ${offset} -ge ${SEGMENT_LENGTH} ]; then
            offset=0
        fi
    done

    # Clean up
    rm "${temp_file}"

    # Handle successful ping
    if [ ${ping_result} -eq 0 ]; then
        animate_segment_completion "${seg_index}" true
        echo -e " ${COLOR_SUCCESS_PRIMARY}✔ ${BOLD}Succeeded${NC}"
        echo -e "   ${COLOR_SUCCESS_ALT}↳ ${success_detail}${NC}"
        return 0
    else
        # Initialize failure type as unknown
        local failure_type="unknown"
        
        # Special handling for Gateway Router test
        if [[ "${description}" == "Gateway Router" ]]; then
            # Check if this might be ICMP filtering
            if echo "${ping_output}" | grep -q "Request timeout"; then
                # Ensure ghost is visible before verification starts
                tput sc
                tput cup $(( progress_row - 1 )) $(( LAST_GHOST_X + FRAME_PADDING ))
                echo -ne "👻"  # Force ghost to be visible
                tput rc

                # Try to reach the internet to determine if it's filtering
                ping -c 5 8.8.8.8 > /dev/null 2>&1 &
                local secondary_ping_pid=$!
                
                # Special animation for the verification process
                local verify_char=("🔎" "🔍" "🔎" "🔍")
                local verify_index=0

                # Animate while the secondary ping is running
                while kill -0 "${secondary_ping_pid}" 2>/dev/null; do
                    # Ensure ghost remains visible during verification
                    tput sc
                    tput cup $(( progress_row - 1 )) $(( LAST_GHOST_X + FRAME_PADDING ))
                    echo -ne "👻"
                
                    # Draw verification character next to the ghost
                    tput cup $(( progress_row - 1 )) $(( LAST_GHOST_X + FRAME_PADDING + 2 ))
                    echo -ne "${COLOR_WARNING}${verify_char[${verify_index}]}${NC}"
                    tput rc

                    # Update spinners
                    draw_spinners

                    # Update index for next animation frame
                    verify_index=$(( (verify_index + 1) % 4 ))
                    sleep 0.2
                done

                # Get the result of secondary ping
                wait "${secondary_ping_pid}"
                local internet_reachable=$?

                # Clear the verification character
                tput sc
                tput cup $(( progress_row - 1 )) $(( LAST_GHOST_X + FRAME_PADDING + 2 ))
                echo -ne "  "
                tput rc

                if [ ${internet_reachable} -eq 0 ]; then
                    # Internet is reachable despite router timeout
                    # The signature of ICMP filtering
                    ROUTER_BLOCKED_SEGMENT=${seg_index}
                    ROUTER_BLOCKED_SYMBOL=$(get_special_symbol "filtered")
                    
                    # Show the icon (🕸️) for filtered traffic
                    draw_failure_segment "${seg_index}" "${ROUTER_BLOCKED_SYMBOL}"
                    
                    # Explain the detected special case
                    special_case_message="${MSG_SPECIAL_CASE_DETECTED/\[SPECIAL_CASE_NAME\]/${MSG_ROUTER_FILTER_DETECTED}}"
                    special_case_message="${special_case_message/\[SPECIAL_SYMBOL\]/${ROUTER_BLOCKED_SYMBOL}}"
                    echo -e " ${COLOR_PROGRESS_COMPLETE}${BOLD}${special_case_message}${NC}"
                    echo -e "   ${COLOR_WARNING}↳ ${MSG_ROUTER_BLOCKING_PING}${NC}"
                    sleep 0.5
                    echo -e "   ${COLOR_SUCCESS_ALT}↳ ${MSG_ICMP_FILTERED}${NC}"
                    sleep 0.5
                    echo -e "   ${COLOR_SUCCESS_PRIMARY}${BOLD}${MSG_CONTINUING_TESTS}${NC}"
                    
                    # Set up and animate the detour path
                    ROUTER_DETOUR_TAKEN=true
                    for step in {1..16}; do
                        draw_router_detour_path ${step}
                        draw_spinners   # Update spinners
                        sleep 0.1       # Ghost movement speed during detour
                    done
                    
                    LAST_SUCCESSFUL_TEST=3
                    return 0
                fi
            fi
        fi
        
        # If below code is triggered, this indicates a genuine failure case but not a special condition:
        # 1. This isn't the Gateway Router test (just a normal test failure)
        # 2. This is the Gateway Router test but ICMP isn't filtered (a real router connectivity problem)
        # 3. This is the Gateway Router test with timeout but internet isn't reachable
        #    (router is up but not properly forwarding traffic)
        failure_type=$(get_primary_failure_type "${ping_output}")

        # Show failure indication and details
        animate_segment_completion "${seg_index}" false "${failure_type}"

        # Get the failure symbol first
        failure_symbol=$(get_failure_symbol "${failure_type}")

        # Use the symbol in the output
        echo -e " ${COLOR_ERROR_PRIMARY}✘ ${BOLD}Failed ${failure_symbol}${NC}"
        echo -e "   ${COLOR_ERROR_DETAIL}↳ ${failure_detail}${NC}"

        sleep 0.5

        # Display recommendations if provided
        if [ -n "${recommendation}" ]; then
            echo -e "   ${COLOR_RECOMMENDATION}${BOLD}↳ Recommended Actions:${NC}"
            echo -e "     ${COLOR_RECOMMENDATION}${recommendation}${NC}"
        fi

        return 1
    fi
}


# ==================================================================
# Main Execution Flow···············································
# ==================================================================
# The tests are executed in sequence, with each test depending on the
# success of previous tests. This represents the layered nature of
# network connectivity, where each layer builds on the previous one.

# --------------
# Initialization
# --------------
print_banner                # Draw the title banner
draw_frame                  # Draw the main UI frame
draw_progress_bar -1 0      # Draw initial empty progress bar
draw_ghost_track 0 0 "👻"   # Position ghost at start

# -------------
# Test Sequence
# -------------
# Local stack -> NIC -> Gateway -> Internet -> DNS

# Test 1: Local Host
# Tests if the basic TCP/IP stack is working
if run_ping_test_animated 1 "127.0.0.1" "Local TCP/IP Stack" \
    "${MSG_LOCAL_STACK_SUCCESS}" \
    "${MSG_LOCAL_STACK_FAILURE}" \
    "${MSG_LOCAL_STACK_RECOMMENDATION}" \
    "🖥️"; then
    LAST_SUCCESSFUL_TEST=1
else
    echo -e "\n${COLOR_WARNING}${BOLD}${MSG_SKIP_AFTER_LOCAL_STACK}${NC}"
    stop_spinners
    sleep 0.5
    echo -e "\n${COLOR_HIGHLIGHT}${BOLD}[${NC}${COLOR_SUCCESS_PRIMARY}${BOLD}1${NC}${COLOR_HIGHLIGHT}${BOLD}/5] Checks completed at ⏱️[$(date '+%Y-%m-%d %H:%M:%S')]${NC}"
fi

# Test 2: Local IP Address
# Tests if the network adapter has a valid IP
if [ ${LAST_SUCCESSFUL_TEST} -eq 1 ]; then
    sleep 0.5
    local_ip=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -n 1)
    if [ -z "${local_ip}" ]; then
        handle_pre_check_failure "no_ip" 1
    elif run_ping_test_animated 2 "${local_ip}" "Network Interface" \
        "${MSG_NETWORK_INTERFACE_SUCCESS}" \
        "${MSG_NETWORK_INTERFACE_FAILURE}" \
        "${MSG_NETWORK_INTERFACE_RECOMMENDATION}" \
        "🎛️"; then
        LAST_SUCCESSFUL_TEST=2
    else
        echo -e "\n${COLOR_WARNING}${BOLD}${MSG_SKIP_AFTER_NETWORK_INTERFACE}${NC}"
        stop_spinners
        sleep 0.5
        echo -e "\n${COLOR_HIGHLIGHT}${BOLD}[${NC}${COLOR_SUCCESS_PRIMARY}${BOLD}2${NC}${COLOR_HIGHLIGHT}${BOLD}/5] Checks completed at ⏱️[$(date '+%Y-%m-%d %H:%M:%S')]${NC}"
    fi
fi

# Test 3: Gateway Router
# Tests if the local network gateway is reachable
if [ ${LAST_SUCCESSFUL_TEST} -eq 2 ]; then
    sleep 0.5
    gateway=$(route -n get default 2>/dev/null | grep gateway | awk '{print $2}')
    if [ -z "${gateway}" ]; then
        handle_pre_check_failure "no_gateway" 2
    elif run_ping_test_animated 3 "${gateway}" "Gateway Router" \
        "${MSG_GATEWAY_ROUTER_SUCCESS}" \
        "${MSG_GATEWAY_ROUTER_FAILURE}" \
        "${MSG_GATEWAY_ROUTER_RECOMMENDATION}" \
        "📡"; then
        LAST_SUCCESSFUL_TEST=3
    else
        echo -e "\n${COLOR_WARNING}${BOLD}${MSG_SKIP_AFTER_GATEWAY_ROUTER}${NC}"
        stop_spinners
        sleep 0.5
        echo -e "\n${COLOR_HIGHLIGHT}${BOLD}[${NC}${COLOR_SUCCESS_PRIMARY}${BOLD}3${NC}${COLOR_HIGHLIGHT}${BOLD}/5] Checks completed at ⏱️[$(date '+%Y-%m-%d %H:%M:%S')]${NC}"
    fi
fi

# Test 4: Internet Connectivity
# Tests if external internet servers are reachable
if [ ${LAST_SUCCESSFUL_TEST} -eq 3 ]; then
    sleep 0.5
    
    # List of targets to try in order (with fallbacks if one fails)
    internet_targets=("8.8.8.8" "1.1.1.1" "9.9.9.9")
    internet_target_names=("Google DNS" "Cloudflare DNS" "Quad9 DNS")
    internet_connectivity_success=false
    
    for i in "${!internet_targets[@]}"; do
        target="${internet_targets[${i}]}"
        target_name="${internet_target_names[${i}]}"
        attempt_num=$((i + 1))
        max_attempts=${#internet_targets[@]}
        
        # Get the moving color for this target
        moving_color="${COLOR_MOVING_ARRAY[${i}]}"
        
        # Show the main header for the first attempt, matching the format of other tests
        if [ ${i} -eq 0 ]; then
            format_test_header "🌐" "Internet Connectivity" "ping ${target}"
        else
            echo -e "   ${COLOR_WARNING}↳ Trying alternate target${NC}${COLOR_PROGRESS_EMPTY} 🔄······························${NC}${COLOR_INDICATOR_ALERT}[ping ${target}]${NC}"
        fi
        
        # Create temporary file for ping output
        temp_file=$(mktemp)
        ping -c 5 "${target}" > "${temp_file}" 2>&1 &
        ping_pid=$!
        
        # Animation variables
        seg_index=3
        offset=0
        ghost_visible=1
        
        # Set minimum animation duration (in seconds)
        min_duration=7
        start_time=$(date +%s)
        ping_completed=false
        
        # Run the animation
        while [ $(( $(date +%s) - start_time )) -lt ${min_duration} ] || ! ${ping_completed}; do
            # Check if ping has completed
            if ! kill -0 "${ping_pid}" 2>/dev/null && ! ${ping_completed}; then
                ping_completed=true
                wait "${ping_pid}"
                ping_result=$?
                ping_output=$(cat "${temp_file}")
            fi
            
            # Continue animation with the appropriate color
            draw_progress_bar "${seg_index}" "${offset}" "${moving_color}"
            if [ ${ghost_visible} -eq 1 ]; then
                ghost_char="👻"
            else
                ghost_char=" "
            fi
            ghost_visible=$(( 1 - ghost_visible ))
            draw_ghost_track "${seg_index}" "0" "${ghost_char}"

            # Update spinners
            draw_spinners

            # Animation timing
            if [ "${ROUTER_DETOUR_TAKEN}" = true ] || [ "${DNS_DETOUR_TAKEN}" = true ]; then
                sleep 0.05  # Faster after detour to keep things snappy
            else
                sleep 0.17  # Normal speed before detour
            fi
            
            # Update progress bar position
            offset=$(( offset + 1 ))
            if [ ${offset} -ge ${SEGMENT_LENGTH} ]; then
                offset=0
            fi
        done
        
        # Clean up
        rm "${temp_file}"
        
        # Handle result
        if [ ${ping_result} -eq 0 ]; then
            animate_segment_completion "${seg_index}" true
            echo -e " ${COLOR_SUCCESS_PRIMARY}✔ ${BOLD}Succeeded${NC}"
            success_message="${MSG_INTERNET_SUCCESS/\[TARGET_NAME\]/${target_name}}"
            echo -e "   ${COLOR_SUCCESS_ALT}↳ ${success_message}${NC}"
            internet_connectivity_success=true
            break
        else
            # Only show permanent failure on last attempt
            failure_type=$(get_primary_failure_type "${ping_output}")
            if [ ${attempt_num} -eq ${max_attempts} ]; then
                animate_segment_completion "${seg_index}" false "${failure_type}"
            fi
            
            failure_symbol=$(get_failure_symbol "${failure_type}")
            echo -e "   ${COLOR_ERROR_DETAIL}✘ Unable to reach [${target_name} Server]${NC}"
        fi
    done
    
    if [ "${internet_connectivity_success}" = true ]; then
        LAST_SUCCESSFUL_TEST=4
    else
        sleep 0.5
        echo -e " ${COLOR_ERROR_PRIMARY}✘ ${BOLD}Failed ${failure_symbol}${NC}"
        echo -e "   ${COLOR_ERROR_DETAIL}↳ ${MSG_INTERNET_FAILURE}${NC}"
        sleep 0.5
        echo -e "   ${COLOR_RECOMMENDATION}${BOLD}↳ Recommended Actions:${NC}"
        echo -e "     ${COLOR_RECOMMENDATION}${MSG_INTERNET_RECOMMENDATION}${NC}"
        sleep 0.5
        echo -e "\n${COLOR_WARNING}${BOLD}${MSG_SKIP_AFTER_INTERNET}${NC}"
        stop_spinners
        sleep 0.5
        echo -e "\n${COLOR_HIGHLIGHT}${BOLD}[${NC}${COLOR_SUCCESS_PRIMARY}${BOLD}4${NC}${COLOR_HIGHLIGHT}${BOLD}/5] Checks completed at ⏱️[$(date '+%Y-%m-%d %H:%M:%S')]${NC}"
    fi
fi

# Test 5: DNS Resolution
# Tests if domain names can be resolved to IP addresses
if [ ${LAST_SUCCESSFUL_TEST} -eq 4 ]; then
    sleep 0.5
    
    # Create temporary file for test results
    dns_result_file=$(mktemp)
    
    # Display test header using customized messages
    format_test_header "🗺️" "${MSG_DNS_CHECK_HEADER}" "${MSG_DNS_CHECK_TARGET}"
    
    # Animation variables
    seg_index=4
    offset=0
    ghost_visible=1
    
    # Check if DNS actually works regardless of configured DNS servers
    # (this determines if a warning or a failure will be shown)
    alt_dns_working="false"
    alt_resolved_domain=""
    alt_resolved_ip=""
    
    # Try to reach google.com directly to test DNS functionality
    if ping -c 1 -W 3 google.com > /dev/null 2>&1; then
        alt_dns_working="true"
        alt_resolved_domain="google.com"
        # Get the IP it resolved to
        if command -v dig &>/dev/null; then
            alt_resolved_ip=$(dig +short google.com | head -n1)
        fi
    fi
    
    # Start testing configured DNS servers in background
    {
        # Store the alternative DNS check results first
        echo "ALT_DNS_WORKING=\"${alt_dns_working}\"" > "${dns_result_file}"
        echo "ALT_RESOLVED_DOMAIN=\"${alt_resolved_domain}\"" >> "${dns_result_file}"
        echo "ALT_RESOLVED_IP=\"${alt_resolved_ip}\"" >> "${dns_result_file}"
        
        # Domains to test with configured DNS servers
        test_domains=("google.com" "cloudflare.com" "microsoft.com")
        
        # Create arrays to store DNS server info
        dns_servers=()
        dns_interfaces=()
        dns_sources=()  # Array to store the source classification

        # On macOS, use 'scutil --dns' (much more accurate than '/etc/resolv.conf')
        if command -v scutil &>/dev/null; then
            # Get DNS configuration
            dns_info=$(scutil --dns 2>/dev/null)
            
            # Parse the resolvers in order of their appearance (which indicates priority)
            # Focus on primary DNS resolvers, not the mdns ones or scoped queries
            vpn_dns_found=false
            
            # Look for VPN DNS first (typically has lowest order number and 'search domain')
            if echo "${dns_info}" | grep -A2 "search domain" | grep -q "100.100.100.100"; then
                vpn_dns_found=true
                vpn_dns=$(echo "${dns_info}" | grep -A2 "search domain" | grep "nameserver" | head -1 | grep -o -E "([0-9]{1,3}\.){3}[0-9]{1,3}")
                vpn_interface=$(echo "${dns_info}" | grep -A2 "search domain" | grep "if_index" | head -1 | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
                
                # Add VPN DNS to the arrays
                if [[ ! " ${dns_servers[@]} " =~ " ${vpn_dns} " ]]; then
                    dns_servers+=("${vpn_dns}")
                    dns_interfaces+=("${vpn_interface}")
                    dns_sources+=("VPN")
                fi
            fi
            
            # If no VPN, check other DNS servers as well
            if [ "${vpn_dns_found}" = false ] || [ ${#dns_servers[@]} -eq 0 ]; then
                # Look at the first resolver entry that isn't for mdns or local domains
                primary_resolver=$(echo "${dns_info}" | grep -A3 "^resolver #[0-9]" | grep -v "domain.*:" | grep "nameserver")
                
                # Get all nameservers from the first resolver
                while read -r nameserver_line; do
                    if [[ "${nameserver_line}" =~ nameserver\[[0-9]+\]\ :\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
                        dns_server="${BASH_REMATCH[1]}"
                        
                        # Determine interface if available
                        interface_line=$(echo "${dns_info}" | grep -A1 "${nameserver_line}" | grep "if_index")
                        if [[ "${interface_line}" =~ if_index\ :\ ([0-9]+)\ \(([a-z0-9]+)\) ]]; then
                            interface="${BASH_REMATCH[2]}"
                        else
                            interface="unknown"
                        fi
                        
                        # Determine source based on IP pattern and context
                        if [[ "${dns_server}" == "100.100.100.100" ]]; then
                            source="VPN"
                        elif [[ "${dns_info}" =~ nameserver\[0\]\ :\ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+.*nameserver\[1\] ]]; then
                            # Multiple nameservers typically indicate manual configuration
                            source="Manual"
                        elif [[ "${dns_server}" =~ ^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
                            source="Router"
                        else
                            source="Manual"  # Assume any non-RFC1918 IP is manually configured
                        fi
                        
                        # Deuplication check
                        if [[ ! " ${dns_servers[@]} " =~ " ${dns_server} " ]]; then
                            dns_servers+=("${dns_server}")
                            dns_interfaces+=("${interface}")
                            dns_sources+=("${source}")
                        fi
                    fi
                done < <(echo "${primary_resolver}")
            fi
        fi

        # If no DNS servers found via 'scutil', try 'resolv.conf' as fallback
        if [ ${#dns_servers[@]} -eq 0 ] && [ -f "/etc/resolv.conf" ]; then
            while read -r dns_server; do
                if [ -n "${dns_server}" ]; then
                    # Determine source based on IP pattern
                    if [[ "${dns_server}" == "100.100.100.100" ]]; then
                        interface="VPN"
                        source="VPN"
                    elif [[ "${dns_server}" =~ ^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
                        interface="eth0"
                        source="Router"
                    else
                        interface="unknown"
                        source="Manual"
                    fi
                    
                    # Deduplication check
                    if [[ ! " ${dns_servers[@]} " =~ " ${dns_server} " ]]; then
                        dns_servers+=("${dns_server}")
                        dns_interfaces+=("${interface}")
                        dns_sources+=("${source}")
                    fi
                fi
            done < <(grep -E "^nameserver" /etc/resolv.conf | awk '{print $2}')
        fi

        # If still no DNS servers found, try networksetup as last resort
        if [ ${#dns_servers[@]} -eq 0 ]; then
            interfaces=("Wi-Fi" "Ethernet")
            for interface in "${interfaces[@]}"; do
                if networksetup -getinfo "${interface}" &>/dev/null; then
                    dns_list=$(networksetup -getdnsservers "${interface}")
                    if [[ "${dns_list}" != *"There aren't any DNS Servers set"* ]]; then
                        for dns in ${dns_list}; do
                            # Determine source based on IP pattern
                            if [[ "${dns}" =~ ^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
                                source="Router"
                            else
                                source="Manual"
                            fi
                            
                            # Deduplication check
                            if [[ ! " ${dns_servers[@]} " =~ " ${dns} " ]]; then
                                dns_servers+=("${dns}")
                                dns_interfaces+=("${interface}")
                                dns_sources+=("${source}")
                            fi
                        done
                    fi
                fi
            done
        fi

        # Store the DNS information
        echo "DNS_SERVER_COUNT=${#dns_servers[@]}" >> "${dns_result_file}"
        for i in "${!dns_servers[@]}"; do
            echo "DNS_SERVER_${i}=\"${dns_servers[${i}]}\"" >> "${dns_result_file}"
            echo "DNS_INTERFACE_${i}=\"${dns_interfaces[${i}]}\"" >> "${dns_result_file}"
            echo "DNS_SOURCE_${i}=\"${dns_sources[${i}]}\"" >> "${dns_result_file}"
        done
        
        # Test each DNS server
        dns_success="false"
        successful_server=""
        successful_domain=""
        resolved_ip=""

        # Track all tested servers and their results
        declare -a tested_servers=()
        declare -a tested_results=()
        declare -a tested_interfaces=()
        declare -a tested_sources=()

        for i in "${!dns_servers[@]}"; do
            dns_server="${dns_servers[${i}]}"
            interface="${dns_interfaces[${i}]}"
            source="${dns_sources[${i}]}"
            server_success="false"
            
            # Try each domain with the DNS server
            for domain in "${test_domains[@]}"; do
                # Use dig with a timeout of 3 seconds if available
                if command -v dig &>/dev/null; then
                    ip_address=$(dig +short +time=3 +tries=1 @"${dns_server}" "${domain}" 2>/dev/null | grep -v ";" | head -n1)
                    
                    # If an IP address is found, the test is successful
                    if [ -n "${ip_address}" ] && [[ "${ip_address}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                        dns_success="true"
                        successful_server="${i}"  # Store the index of successful server
                        successful_domain="${domain}"
                        resolved_ip="${ip_address}"
                        server_success="true"
                        break 1  # Break out of domain loop but continue to record this server
                    fi
                else
                    # Fallback to nslookup if dig not available
                    ip_address=$(nslookup "${domain}" "${dns_server}" 2>/dev/null | grep -A2 "Name:" | grep "Address:" | head -n1 | awk '{print $2}')
                    
                    if [ -n "${ip_address}" ] && [[ "${ip_address}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                        dns_success="true"
                        successful_server="${i}"  # Store index
                        successful_domain="${domain}"
                        resolved_ip="${ip_address}"
                        server_success="true"
                        break 1
                    fi
                fi
            done
            
            # Record this server and its result
            tested_servers+=("${dns_server}")
            tested_interfaces+=("${interface}")
            tested_sources+=("${source}")
            tested_results+=("${server_success}")
            
            # If this server succeeded, stop testing more servers
            if [ "${server_success}" = "true" ]; then
                break
            fi
        done

        # Store the test results
        echo "DNS_SUCCESS=\"${dns_success}\"" >> "${dns_result_file}"
        echo "SUCCESSFUL_SERVER=\"${successful_server}\"" >> "${dns_result_file}"
        echo "SUCCESSFUL_DOMAIN=\"${successful_domain}\"" >> "${dns_result_file}"
        echo "RESOLVED_IP=\"${resolved_ip}\"" >> "${dns_result_file}"

        # Store the array of tested servers
        echo "TESTED_SERVER_COUNT=${#tested_servers[@]}" >> "${dns_result_file}"
        for i in "${!tested_servers[@]}"; do
            echo "TESTED_SERVER_${i}=\"${tested_servers[${i}]}\"" >> "${dns_result_file}"
            echo "TESTED_INTERFACE_${i}=\"${tested_interfaces[${i}]}\"" >> "${dns_result_file}"
            echo "TESTED_SOURCE_${i}=\"${tested_sources[${i}]}\"" >> "${dns_result_file}"
            echo "TESTED_RESULT_${i}=\"${tested_results[${i}]}\"" >> "${dns_result_file}"
        done
    } &
    
    dns_test_pid=$!
    
    # Set minimum animation duration (in seconds)
    min_duration=7
    start_time=$(date +%s)
    dns_test_completed=false
    
    # Run the animation while test completes
    while [ $(( $(date +%s) - start_time )) -lt ${min_duration} ] || ! ${dns_test_completed}; do
        # Check if DNS test has completed
        if ! kill -0 "${dns_test_pid}" 2>/dev/null && ! ${dns_test_completed}; then
            dns_test_completed=true
        fi
        
        # Continue animation
        draw_progress_bar "${seg_index}" "${offset}"
        if [ ${ghost_visible} -eq 1 ]; then
            ghost_char="👻"
        else
            ghost_char=" "
        fi
        ghost_visible=$(( 1 - ghost_visible ))
        draw_ghost_track "${seg_index}" "0" "${ghost_char}"
        
        # Update spinners
        draw_spinners

        # Animation timing
        if [ "${ROUTER_DETOUR_TAKEN}" = true ] || [ "${DNS_DETOUR_TAKEN}" = true ]; then
            sleep 0.05  # Faster after detour to keep things snappy
        else
            sleep 0.17  # Normal speed before detour
        fi
        
        # Update progress bar position
        offset=$(( offset + 1 ))
        if [ ${offset} -ge ${SEGMENT_LENGTH} ]; then
            offset=0
        fi
    done
    
    # Kill DNS test if still running
    if kill -0 "${dns_test_pid}" 2>/dev/null; then
        kill "${dns_test_pid}" 2>/dev/null
    fi
    
    # Source the results file
    if [ -f "${dns_result_file}" ]; then
        source "${dns_result_file}"
    else
        # Fallback if file wasn't created
        DNS_SUCCESS="false"
        ALT_DNS_WORKING="false"
    fi
    
    # Process the test results
    if [ "${DNS_SUCCESS}" = "true" ]; then
        # DNS resolution with configured servers succeeded
        animate_segment_completion "${seg_index}" true
        echo -e " ${COLOR_SUCCESS_PRIMARY}✔ ${BOLD}Succeeded${NC}"
        
        # Get the source of the first successful DNS server
        server_idx=${SUCCESSFUL_SERVER}
        source_var="DNS_SOURCE_${server_idx}"
        dns_source="${!source_var:-Unknown}"
        
        # Customize message based on DNS source
        case "${dns_source}" in
            "Router")
                echo -e "   ${COLOR_SUCCESS_ALT}↳ ${MSG_DNS_ROUTER_SUCCESS}${NC}"
                ;;
            "VPN")
                echo -e "   ${COLOR_SUCCESS_ALT}↳ ${MSG_DNS_VPN_SUCCESS}${NC}"
                ;;
            "Manual")
                echo -e "   ${COLOR_SUCCESS_ALT}↳ ${MSG_DNS_MANUAL_SUCCESS}${NC}"
                ;;
            *)
                echo -e "   ${COLOR_SUCCESS_ALT}↳ ${MSG_DNS_OTHER_SUCCESS}${NC}"
                ;;
        esac
        
        # Display all tested servers with their results
        tested_count=${TESTED_SERVER_COUNT:-0}
        for ((i=0; i<tested_count; i++)); do
            server_var="TESTED_SERVER_${i}"
            source_var="TESTED_SOURCE_${i}"
            result_var="TESTED_RESULT_${i}"
            
            # Format the source label nicely
            dns_source="${!source_var:-Unknown}"
            
            if [ "${!result_var}" = "true" ]; then
                # This server succeeded
                echo -e "     ${COLOR_SUCCESS_PRIMARY}✔ ${!server_var} (${dns_source})${NC}"
            else
                # This server failed
                echo -e "     ${COLOR_ERROR_PRIMARY}✘ ${!server_var} (${dns_source})${NC}"
            fi
        done
        
        if [ -n "${SUCCESSFUL_DOMAIN}" ] && [ -n "${RESOLVED_IP}" ]; then
            message="${MSG_DNS_SUCCESS_RESOLUTION/\[DOMAIN\]/${SUCCESSFUL_DOMAIN}}"
            message="${message/\[IP_ADDRESS\]/${RESOLVED_IP}}"
            echo -e "   ${COLOR_SUCCESS_ALT}↳ ${message}${NC}"
        fi
        
        LAST_SUCCESSFUL_TEST=5
        USING_ALT_DNS="false"
    else
        # Check if any DNS servers could be found to test
        if [ ${DNS_SERVER_COUNT:-0} -eq 0 ]; then
            # No DNS servers could be found at all - rely on alternative resolution detection
            if [ "${ALT_DNS_WORKING}" = "true" ]; then
                
                # DNS resolution works through alternative mechanisms
                DNS_BLOCKED_SEGMENT=${seg_index}
                DNS_BLOCKED_SYMBOL=$(get_special_symbol "dns_alt")
                
                # Show the alternative DNS symbol
                draw_failure_segment "${seg_index}" "${DNS_BLOCKED_SYMBOL}"
                
                # Inform user about the special case
                special_case_message="${MSG_SPECIAL_CASE_DETECTED/\[SPECIAL_CASE_NAME\]/${MSG_DNS_ALT_DETECTED}}"
                special_case_message="${special_case_message/\[SPECIAL_SYMBOL\]/${DNS_BLOCKED_SYMBOL}}"
                echo -e " ${COLOR_PROGRESS_COMPLETE}${BOLD}${special_case_message}${NC}"
                
                echo -e "   ${COLOR_WARNING}↳ ${MSG_NO_DNS_DETECTED}${NC}"
                sleep 0.5
                echo -e "   ${COLOR_WARNING}↳ ${MSG_DNS_ALT_WORKS_NO_SERVERS}${NC}"
                echo -e "   ${COLOR_WARNING}  ${MSG_DNS_ALT_DETAIL}${NC}"
                
                # Set flag for right dot line
                DNS_RIGHT_DOT_LINE_DRAWN=true
                sleep 0.5
                
                if [ -n "${ALT_RESOLVED_DOMAIN}" ]; then
                    if [ -n "${ALT_RESOLVED_IP}" ]; then
                        # Format with IP address
                        ip_info=" → ${ALT_RESOLVED_IP}"
                        message="${MSG_DNS_ALT_RESOLVED/\[DOMAIN\]/${ALT_RESOLVED_DOMAIN}}"
                        message="${message/\[IP_INFO\]/${ip_info}}"
                        echo -e "     ${COLOR_SUCCESS_ALT}↳ ${message}${NC}"
                    else
                        # Format without IP address
                        message="${MSG_DNS_ALT_RESOLVED/\[DOMAIN\]/${ALT_RESOLVED_DOMAIN}}"
                        message="${message/\[IP_INFO\]/}"
                        echo -e "     ${COLOR_SUCCESS_ALT}↳ ${message}${NC}"
                    fi
                fi
                sleep 0.5
                
                echo -e "   ${COLOR_SUCCESS_PRIMARY}${BOLD}${MSG_DNS_ALT_SUCCESS}${NC}"
                
                # Set up and animate the DNS detour path
                DNS_DETOUR_TAKEN=true
                for step in {1..16}; do
                    draw_dns_detour_path ${step}
                    draw_spinners   # Update spinners
                    sleep 0.1       # Ghost movement speed during detour
                done
                
                LAST_SUCCESSFUL_TEST=5
                USING_ALT_DNS="true"
            else
                # No DNS servers detected and alternative resolution doesn't work
                animate_segment_completion "${seg_index}" false "unknown"
                echo -e " ${COLOR_ERROR_PRIMARY}✘ ${BOLD}Failed $(get_failure_symbol "unknown")${NC}"
                echo -e "   ${COLOR_ERROR_DETAIL}↳ ${MSG_NO_DNS_DETECTED}${NC}"
                echo -e "   ${COLOR_ERROR_DETAIL}↳ ${MSG_NO_DNS_NO_RESOLUTION}${NC}"
                
                sleep 0.5
                echo -e "   ${COLOR_RECOMMENDATION}${BOLD}↳ Recommended Actions:${NC}"
                echo -e "     ${COLOR_RECOMMENDATION}${MSG_MANUAL_DNS_CONFIG_RECOMMENDATION}${NC}"
            fi
        elif [ "${ALT_DNS_WORKING}" = "true" ]; then
            # DNS resolution with configured servers failed but alternative DNS is working
            DNS_BLOCKED_SEGMENT=${seg_index}
            DNS_BLOCKED_SYMBOL=$(get_special_symbol "dns_alt")
            
            dns_verify_char=("⏳" "⌛" "⏳" "⌛")
            dns_verify_index=0

            # Animate the verification process
            for ((i=0; i<10; i++)); do  # Run for a set number of iterations
                # Ensure ghost remains visible during verification
                tput sc
                tput cup $(( progress_row - 1 )) $(( LAST_GHOST_X + FRAME_PADDING ))
                echo -ne "👻"

                # Draw verification character next to the ghost
                tput cup $(( progress_row - 1 )) $(( LAST_GHOST_X + FRAME_PADDING + 2 ))
                echo -ne "${COLOR_WARNING}${dns_verify_char[${dns_verify_index}]}${NC}"
                tput rc

                # Update spinners
                draw_spinners

                # Update index for next animation frame
                dns_verify_index=$(( (dns_verify_index + 1) % 4 ))
                sleep 0.2
            done

            # Clear the verification character
            tput sc
            tput cup $(( progress_row - 1 )) $(( LAST_GHOST_X + FRAME_PADDING + 2 ))
            echo -ne "  "
            tput rc

            # Show the recycling symbol for alternative DNS
            draw_failure_segment "${seg_index}" "${DNS_BLOCKED_SYMBOL}"

            # Inform user about the special case
            special_case_message="${MSG_SPECIAL_CASE_DETECTED/\[SPECIAL_CASE_NAME\]/${MSG_DNS_ALT_DETECTED}}"
            special_case_message="${special_case_message/\[SPECIAL_SYMBOL\]/${DNS_BLOCKED_SYMBOL}}"
            echo -e " ${COLOR_PROGRESS_COMPLETE}${BOLD}${special_case_message}${NC}"
            
            # Display the configured DNS servers
            count=${DNS_SERVER_COUNT:-0}
            if [ "${count}" -gt 0 ]; then
                echo -e "   ${COLOR_WARNING}↳ ${MSG_DNS_ALT_WARNING}${NC}"
                for ((i=0; i<count; i++)); do
                    server_var="DNS_SERVER_${i}"
                    source_var="DNS_SOURCE_${i}"
                    dns_source="${!source_var:-Unknown}"
                    echo -e "     ${COLOR_ERROR_DETAIL}✘ ${!server_var} (${dns_source})${NC}"
                done
            fi
            sleep 0.5

            echo -e "   ${COLOR_WARNING}↳ ${MSG_DNS_ALT_WORKS_NO_SERVERS}${NC}"
            echo -e "   ${COLOR_WARNING}  ${MSG_DNS_ALT_DETAIL}${NC}"
            
            # Set flag for right dot line
            DNS_RIGHT_DOT_LINE_DRAWN=true
            sleep 0.5

            if [ -n "${ALT_RESOLVED_DOMAIN}" ]; then
                if [ -n "${ALT_RESOLVED_IP}" ]; then
                    # Format with IP address
                    ip_info=" → ${ALT_RESOLVED_IP}"
                    message="${MSG_DNS_ALT_RESOLVED/\[DOMAIN\]/${ALT_RESOLVED_DOMAIN}}"
                    message="${message/\[IP_INFO\]/${ip_info}}"
                    echo -e "     ${COLOR_SUCCESS_ALT}↳ ${message}${NC}"
                else
                    # Format without IP address
                    message="${MSG_DNS_ALT_RESOLVED/\[DOMAIN\]/${ALT_RESOLVED_DOMAIN}}"
                    message="${message/\[IP_INFO\]/}"
                    echo -e "     ${COLOR_SUCCESS_ALT}↳ ${message}${NC}"
                fi
            fi
            sleep 0.5

            echo -e "   ${COLOR_SUCCESS_PRIMARY}${BOLD}${MSG_DNS_ALT_SUCCESS}${NC}"

            # Set up and animate the DNS detour path
            DNS_DETOUR_TAKEN=true
            for step in {1..16}; do
                draw_dns_detour_path ${step}
                draw_spinners   # Update spinners
                sleep 0.1       # Ghost movement speed during detour
            done

            LAST_SUCCESSFUL_TEST=5
            USING_ALT_DNS="true"
        else
            # True DNS failure - can't resolve hostnames
            animate_segment_completion "${seg_index}" false "unknown"
            echo -e " ${COLOR_ERROR_PRIMARY}✘ ${BOLD}Failed $(get_failure_symbol "unknown")${NC}"
            
            # Display the configured DNS servers
            count=${DNS_SERVER_COUNT:-0}
            if [ "${count}" -gt 0 ]; then
                echo -e "   ${COLOR_ERROR_DETAIL}↳ ${MSG_DNS_FAILURE}${NC}"
                for ((i=0; i<count; i++)); do
                    server_var="DNS_SERVER_${i}"
                    source_var="DNS_SOURCE_${i}"
                    dns_source="${!source_var:-Unknown}"
                    echo -e "     ${COLOR_ERROR_DETAIL}✘ ${!server_var} (${dns_source})${NC}"
                
                    if [ $i -eq 0 ]; then
                        primary_dns_source="${dns_source}"
                    fi
                done
                sleep 0.5

                # Provide source-specific troubleshooting advice
                case "${primary_dns_source}" in
                    "Router")
                        echo -e "   ${COLOR_RECOMMENDATION}${BOLD}↳ Recommended Actions:${NC}"
                        echo -e "     ${COLOR_RECOMMENDATION}${MSG_DNS_ROUTER_RECOMMENDATION}${NC}"
                        ;;
                    "VPN")
                        echo -e "   ${COLOR_RECOMMENDATION}${BOLD}↳ Recommended Actions:${NC}"
                        echo -e "     ${COLOR_RECOMMENDATION}${MSG_DNS_VPN_RECOMMENDATION}${NC}"
                        ;;
                    "Manual")
                        echo -e "   ${COLOR_RECOMMENDATION}${BOLD}↳ Recommended Actions:${NC}"
                        echo -e "     ${COLOR_RECOMMENDATION}${MSG_DNS_MANUAL_RECOMMENDATION}${NC}"
                        ;;
                    *)
                        echo -e "   ${COLOR_RECOMMENDATION}${BOLD}↳ Recommended Actions:${NC}"
                        echo -e "     ${COLOR_RECOMMENDATION}${MSG_DNS_GENERIC_RECOMMENDATION}${NC}"
                        ;;
                esac
            fi
        fi
    fi
    
    # Clean up
    rm -f "${dns_result_file}"
    
    stop_spinners
    sleep 0.5
    echo -e "\n${COLOR_HIGHLIGHT}${BOLD}[${NC}${COLOR_SUCCESS_PRIMARY}${BOLD}5${NC}${COLOR_HIGHLIGHT}${BOLD}/5] Checks completed at ⏱️[$(date '+%Y-%m-%d %H:%M:%S')]${NC}"
fi

# ==================================================================
# Final Results and Summary·········································
# ==================================================================
# This section displays the final test results and summary information,
# including special cases detected and overall network status.

# Handle special detection cases first
if [ ${LAST_SUCCESSFUL_TEST} -eq 5 ]; then
    # All tests successful - show success message
    sleep 0.5
    echo ""
    echo -e "${COLOR_SUCCESS_PRIMARY}${BOLD}${MSG_FINAL_SUCCESS}${NC}"
    
    # Handle special case: ICMP filtering (detour path)
    if [ "${ROUTER_DETOUR_TAKEN}" = true ]; then
        echo -e "${COLOR_ACCENT_LAVENDER}${BOLD}${MSG_ROUTER_FILTERING}${NC}"
        echo -e "${COLOR_ACCENT_PINK}   • ${MSG_ROUTER_FILTERING_DETAIL_1}${NC}"
        echo -e "${COLOR_ACCENT_PINK}   • ${NC}${MSG_ROUTER_FILTERING_DETAIL_2}${NC}"
    fi
    
    # Handle special case: Alternative DNS resolution
    if [ "${USING_ALT_DNS}" = true ]; then
        echo -e "${COLOR_ACCENT_LAVENDER}${BOLD}${MSG_DNS_ALT_FINAL}${NC}"
        echo -e "${COLOR_ACCENT_PINK}   • ${MSG_DNS_ALT_FINAL_DETAIL_1}${NC}"
        echo -e "${COLOR_ACCENT_PINK}   • ${NC}${MSG_DNS_ALT_FINAL_DETAIL_2}${NC}"
    fi
else
    # Some tests failed - show failure message
    sleep 0.5
    echo ""
    echo -e "${COLOR_ERROR_PRIMARY}${BOLD}${MSG_FINAL_FAILURE}${NC}"
    echo -e "${COLOR_ERROR_PRIMARY}${BOLD}${MSG_FINAL_REVIEW}${NC}"
fi

# ==================================================================
# Cleanup and Exit··················································
# ==================================================================
# This section performs final cleanup operations before exiting.

# Clean up any temporary files or processes
trap 'rm -f "${temp_file}" 2>/dev/null' EXIT

# Restore cursor visibility before finishing
tput cnorm

# Return success status
return 0 2>/dev/null || exit 0