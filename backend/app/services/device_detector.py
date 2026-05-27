import re
from typing import Dict, Any

def parse_device_info(user_agent: str) -> Dict[str, str]:
    """
    Parse User-Agent string to detect browser, operating system, device type, and platform.
    """
    if not user_agent:
        return {
            "browser": "Unknown Browser",
            "os": "Unknown OS",
            "device_type": "Unknown Device",
            "platform": "Web"
        }
        
    ua = user_agent.lower()
    
    # Default values
    browser = "Unknown Browser"
    os = "Unknown OS"
    device_type = "Unknown Device"
    platform = "Web" # Web / Android / iOS / Desktop
    
    # 1. OS Detection
    if "windows" in ua:
        os = "Windows"
        platform = "Desktop"
    elif "macintosh" in ua or "mac os x" in ua:
        os = "macOS"
        platform = "Desktop"
    elif "linux" in ua and "android" not in ua:
        os = "Linux"
        platform = "Desktop"
    elif "android" in ua:
        os = "Android"
        platform = "Android"
    elif "iphone" in ua:
        os = "iOS"
        platform = "iOS"
        device_type = "iPhone"
    elif "ipad" in ua:
        os = "iOS"
        platform = "iOS"
        device_type = "iPad"
    elif "ipod" in ua:
        os = "iOS"
        platform = "iOS"
        device_type = "iPod"
        
    # 2. Browser/App Detection
    if "dart" in ua:
        browser = "Flutter Client"
        device_type = "Mobile App"
    elif "code genie android" in ua or "android app" in ua:
        browser = "Android App"
        device_type = "Android"
        platform = "Android"
    elif "code genie ios" in ua or "iphone app" in ua:
        browser = "iOS App"
        device_type = "iPhone"
        platform = "iOS"
    elif "edge" in ua or "edg/" in ua:
        browser = "Edge"
        if device_type == "Unknown Device":
            device_type = "Desktop"
    elif "chrome" in ua and "safari" in ua and "edge" not in ua and "edg/" not in ua:
        browser = "Chrome"
        if "android" in ua:
            device_type = "Android Phone"
        elif "iphone" in ua or "ipad" in ua:
            device_type = "iPhone" if "iphone" in ua else "iPad"
        else:
            device_type = "Desktop"
    elif "safari" in ua and "chrome" not in ua:
        browser = "Safari"
        if "iphone" in ua or "ipad" in ua:
            device_type = "iPhone" if "iphone" in ua else "iPad"
        else:
            device_type = "Desktop"
    elif "firefox" in ua:
        browser = "Firefox"
        if "android" in ua or "iphone" in ua:
            device_type = "Mobile"
        else:
            device_type = "Desktop"
            
    # Platform specific default device names
    if device_type == "Unknown Device":
        if platform == "Desktop":
            device_type = "Desktop"
        elif platform == "Android":
            device_type = "Android Device"
        elif platform == "iOS":
            device_type = "iPhone/iPad"
            
    return {
        "browser": browser,
        "os": os,
        "device_type": device_type,
        "platform": platform
    }
