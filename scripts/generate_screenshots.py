"""
Production Screenshot Generator for WebotApp POS
Generates pixel-perfect, crisp, supersampled UI showcases for GitHub README.
"""

import os
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "docs", "screenshots")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Colors
BG_DESKTOP = (248, 250, 252)        # #F8FAFC
SIDEBAR_BG = (15, 23, 42)          # #0F172A
SIDEBAR_ACTIVE = (30, 41, 59)      # #1E293B
SIDEBAR_TEXT = (148, 163, 184)     # #94A3B8
SIDEBAR_TEXT_ACTIVE = (255, 255, 255)
CARD_BG = (255, 255, 255)
BORDER_COLOR = (226, 232, 240)     # #E2E8F0
TEXT_MAIN = (15, 23, 42)           # #0F172A
TEXT_MUTED = (100, 116, 139)       # #64748B
TEXT_LIGHT = (148, 163, 184)       # #94A3B8

PRIMARY_INDIGO = (99, 102, 241)    # #6366F1
PRIMARY_DARK = (79, 70, 229)       # #4F46E5
SUCCESS_EMERALD = (16, 185, 129)   # #10B981
SUCCESS_BG = (209, 250, 229)       # #D1FAE5
WARNING_AMBER = (245, 158, 11)     # #F59E0B
WARNING_BG = (254, 243, 199)       # #FEF3C7
DANGER_ROSE = (239, 68, 68)        # #EF4444
DANGER_BG = (254, 226, 226)        # #FEE2E2
ORANGE_EXPIRY = (249, 115, 22)     # #F97316
ORANGE_BG = (255, 237, 213)

# Fonts
FONT_REGULAR = "C:/Windows/Fonts/segoeui.ttf"
FONT_SEMIBOLD = "C:/Windows/Fonts/seguisb.ttf"
FONT_BOLD = "C:/Windows/Fonts/segoeuib.ttf"
FONT_MONO = "C:/Windows/Fonts/consola.ttf"

def get_font(path, size, scale=2):
    try:
        return ImageFont.truetype(path, size * scale)
    except Exception:
        return ImageFont.load_default()

def draw_window_chrome(draw, w, h, title="WebotApp POS Admin — Retail Intelligence Node", scale=2):
    titlebar_h = 38 * scale
    draw.rectangle([0, 0, w, titlebar_h], fill=(241, 245, 249))
    draw.line([0, titlebar_h, w, titlebar_h], fill=(226, 232, 240), width=max(1, scale))
    
    # App title & Badge
    f_title = get_font(FONT_SEMIBOLD, 12, scale)
    draw.text((18 * scale, 10 * scale), title, fill=(51, 65, 85), font=f_title)
    
    # Window controls
    cw = 12 * scale
    gap = 8 * scale
    rx = w - 18 * scale
    cy = 19 * scale
    draw.ellipse([rx - cw, cy - cw//2, rx, cy + cw//2], fill=(239, 68, 68))
    rx -= cw + gap
    draw.ellipse([rx - cw, cy - cw//2, rx, cy + cw//2], fill=(245, 158, 11))
    rx -= cw + gap
    draw.ellipse([rx - cw, cy - cw//2, rx, cy + cw//2], fill=(16, 185, 129))

def draw_sidebar(draw, scale=2, active_index=0, w=1440, h=900):
    sb_w = 230 * scale
    start_y = 38 * scale
    total_h = h * scale
    
    draw.rectangle([0, start_y, sb_w, total_h], fill=SIDEBAR_BG)
    
    # Brand
    f_brand = get_font(FONT_BOLD, 15, scale)
    f_sub = get_font(FONT_SEMIBOLD, 9, scale)
    draw.text((22 * scale, start_y + 20 * scale), "⚡ WEBOTAPP POS", fill=(255, 255, 255), font=f_brand)
    draw.text((22 * scale, start_y + 44 * scale), "HYBRID RETAIL OS • DESKTOP", fill=SIDEBAR_TEXT, font=f_sub)
    
    items = [
        ("Dashboard", "📊", 0),
        ("Sales & Bills", "🧾", 0),
        ("Product Catalog", "📦", 0),
        ("Low Stock", "⚠️", 12),
        ("Expiry Tracker", "⏳", 6),
        ("Employees", "👥", 0),
        ("Terminals", "📡", 0),
        ("Database Backup", "💾", 0),
    ]
    
    curr_y = start_y + 76 * scale
    item_h = 44 * scale
    pad = 12 * scale
    
    f_item = get_font(FONT_SEMIBOLD, 12, scale)
    f_badge = get_font(FONT_BOLD, 9, scale)
    
    for idx, (label, icon, badge) in enumerate(items):
        is_active = (idx == active_index)
        box = [pad, curr_y, sb_w - pad, curr_y + item_h]
        if is_active:
            draw.rounded_rectangle(box, radius=8 * scale, fill=SIDEBAR_ACTIVE)
            draw.rounded_rectangle([pad, curr_y + 8 * scale, pad + 4 * scale, curr_y + item_h - 8 * scale], radius=2 * scale, fill=PRIMARY_INDIGO)
        
        color = SIDEBAR_TEXT_ACTIVE if is_active else SIDEBAR_TEXT
        draw.text((pad + 18 * scale, curr_y + 12 * scale), f"{icon}  {label}", fill=color, font=f_item)
        
        if badge > 0:
            badge_color = DANGER_ROSE if idx == 3 else ORANGE_EXPIRY
            bx = sb_w - pad - 30 * scale
            by = curr_y + 13 * scale
            draw.rounded_rectangle([bx, by, bx + 22 * scale, by + 18 * scale], radius=9 * scale, fill=badge_color)
            draw.text((bx + 5 * scale, by + 2 * scale), f"{badge}", fill=(255, 255, 255), font=f_badge)
            
        curr_y += item_h + 4 * scale

    # Server Status Card
    bottom_y = total_h - 76 * scale
    draw.rounded_rectangle([pad, bottom_y, sb_w - pad, bottom_y + 58 * scale], radius=8 * scale, fill=(30, 41, 59))
    draw.ellipse([pad + 14 * scale, bottom_y + 18 * scale, pad + 24 * scale, bottom_y + 28 * scale], fill=SUCCESS_EMERALD)
    f_srv = get_font(FONT_BOLD, 11, scale)
    f_srv_sub = get_font(FONT_MONO, 9, scale)
    draw.text((pad + 30 * scale, bottom_y + 12 * scale), "Shelf Sync Daemon Online", fill=(241, 245, 249), font=f_srv)
    draw.text((pad + 30 * scale, bottom_y + 30 * scale), "0.0.0.0:8085 • 2 Mobiles Paired", fill=SIDEBAR_TEXT, font=f_srv_sub)

    return sb_w

def draw_kpi_card(draw, x, y, w, h, title, value, subtitle, trend, icon, scale=2, accent=PRIMARY_INDIGO):
    draw.rounded_rectangle([x, y, x + w, y + h], radius=10 * scale, fill=CARD_BG, outline=BORDER_COLOR, width=max(1, scale))
    draw.line([x, y + 3 * scale, x + w, y + 3 * scale], fill=accent, width=3 * scale)
    
    f_title = get_font(FONT_SEMIBOLD, 11, scale)
    f_val = get_font(FONT_BOLD, 22, scale)
    f_sub = get_font(FONT_REGULAR, 10, scale)
    f_trend = get_font(FONT_BOLD, 10, scale)
    
    draw.text((x + 16 * scale, y + 16 * scale), title, fill=TEXT_MUTED, font=f_title)
    draw.text((x + 16 * scale, y + 38 * scale), value, fill=TEXT_MAIN, font=f_val)
    draw.text((x + 16 * scale, y + 78 * scale), subtitle, fill=TEXT_LIGHT, font=f_sub)
    
    # Trend pill
    if trend:
        tw = 68 * scale
        th = 20 * scale
        tx = x + w - tw - 16 * scale
        ty = y + 16 * scale
        is_pos = "+" in trend or "UP" in trend
        bg_col = SUCCESS_BG if is_pos else WARNING_BG
        txt_col = SUCCESS_EMERALD if is_pos else WARNING_AMBER
        draw.rounded_rectangle([tx, ty, tx + tw, ty + th], radius=10 * scale, fill=bg_col)
        draw.text((tx + 8 * scale, ty + 2 * scale), trend, fill=txt_col, font=f_trend)

def generate_dashboard():
    scale = 2
    w, h = 1440, 900
    im = Image.new("RGB", (w * scale, h * scale), BG_DESKTOP)
    draw = ImageDraw.Draw(im)
    
    draw_window_chrome(draw, w * scale, h * scale, scale=scale)
    sb_w = draw_sidebar(draw, scale=scale, active_index=0, w=w, h=h)
    
    content_x = sb_w + 28 * scale
    content_w = (w * scale) - content_x - 28 * scale
    
    # Header
    header_y = 62 * scale
    f_h1 = get_font(FONT_BOLD, 20, scale)
    f_h_sub = get_font(FONT_REGULAR, 11, scale)
    draw.text((content_x, header_y), "Store Executive Dashboard", fill=TEXT_MAIN, font=f_h1)
    draw.text((content_x, header_y + 28 * scale), "Real-time revenue, gross margin, tax compliance, and inventory throughput", fill=TEXT_MUTED, font=f_h_sub)
    
    # Date Range Pills
    pills = ["Today", "Yesterday", "Last 7 Days", "This Month"]
    px = content_x + content_w - 320 * scale
    for i, p in enumerate(pills):
        pw = 74 * scale
        is_sel = (i == 0)
        bg = PRIMARY_INDIGO if is_sel else CARD_BG
        fg = (255, 255, 255) if is_sel else TEXT_MUTED
        draw.rounded_rectangle([px, header_y + 6 * scale, px + pw, header_y + 34 * scale], radius=6 * scale, fill=bg, outline=BORDER_COLOR, width=scale)
        f_p = get_font(FONT_SEMIBOLD, 10, scale)
        draw.text((px + 12 * scale, header_y + 12 * scale), p, fill=fg, font=f_p)
        px += pw + 8 * scale

    # 4 KPI Cards
    kpi_y = header_y + 62 * scale
    gap = 16 * scale
    card_w = (content_w - 3 * gap) // 4
    card_h = 108 * scale
    
    draw_kpi_card(draw, content_x + 0 * (card_w + gap), kpi_y, card_w, card_h, "TODAY'S GROSS REVENUE", "₹58,420.00", "184 bills generated", "+18.4% vs yday", "💰", scale, SUCCESS_EMERALD)
    draw_kpi_card(draw, content_x + 1 * (card_w + gap), kpi_y, card_w, card_h, "ESTIMATED NET MARGIN", "₹16,845.00", "28.8% gross margin", "+3.2%", "📈", scale, PRIMARY_INDIGO)
    draw_kpi_card(draw, content_x + 2 * (card_w + gap), kpi_y, card_w, card_h, "AVERAGE BASKET SIZE", "₹317.50", "4.6 items per transaction", "Steady", "🛒", scale, WARNING_AMBER)
    draw_kpi_card(draw, content_x + 3 * (card_w + gap), kpi_y, card_w, card_h, "OFFLINE SYNC STATUS", "100% HEALTHY", "0 unsynced bills in queue", "0.4ms ping", "⚡", scale, SUCCESS_EMERALD)

    # Middle Section: Sales Trend Chart (Left 65%) & Payment Split (Right 35%)
    mid_y = kpi_y + card_h + 20 * scale
    mid_h = 280 * scale
    chart_w = int(content_w * 0.64)
    split_w = content_w - chart_w - gap
    
    # Sales Chart Card
    draw.rounded_rectangle([content_x, mid_y, content_x + chart_w, mid_y + mid_h], radius=10 * scale, fill=CARD_BG, outline=BORDER_COLOR, width=scale)
    f_ctitle = get_font(FONT_BOLD, 13, scale)
    draw.text((content_x + 20 * scale, mid_y + 18 * scale), "Hourly Sales Velocity (₹ Revenue / Hour)", fill=TEXT_MAIN, font=f_ctitle)
    
    # Draw Bar Chart
    hours = ["08:00", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00", "22:00"]
    sales_h = [2400, 5800, 8900, 4200, 7100, 11400, 14200, 4420]
    max_sale = 16000
    bar_base_y = mid_y + mid_h - 45 * scale
    chart_avail_h = 170 * scale
    bar_w = 42 * scale
    c_gap = (chart_w - 60 * scale - len(hours) * bar_w) // (len(hours) - 1)
    
    f_bar_lbl = get_font(FONT_SEMIBOLD, 9, scale)
    f_bar_val = get_font(FONT_MONO, 8, scale)
    
    for i, (hr, val) in enumerate(zip(hours, sales_h)):
        bx = content_x + 30 * scale + i * (bar_w + c_gap)
        bh = int((val / max_sale) * chart_avail_h)
        by = bar_base_y - bh
        # Bar gradient/fill
        draw.rounded_rectangle([bx, by, bx + bar_w, bar_base_y], radius=4 * scale, fill=PRIMARY_INDIGO)
        draw.text((bx + 2 * scale, bar_base_y + 8 * scale), hr, fill=TEXT_MUTED, font=f_bar_lbl)
        draw.text((bx + 2 * scale, by - 16 * scale), f"₹{val//1000}k", fill=TEXT_MAIN, font=f_bar_val)

    # Payment Breakdown Card
    split_x = content_x + chart_w + gap
    draw.rounded_rectangle([split_x, mid_y, split_x + split_w, mid_y + mid_h], radius=10 * scale, fill=CARD_BG, outline=BORDER_COLOR, width=scale)
    draw.text((split_x + 20 * scale, mid_y + 18 * scale), "Tender Modes & Settlement", fill=TEXT_MAIN, font=f_ctitle)
    
    # Payment modes progress bars
    tenders = [
        ("UPI / Dynamic QR", "₹30,378.40", 52, SUCCESS_EMERALD),
        ("Cash Register", "₹22,199.60", 38, PRIMARY_INDIGO),
        ("Credit / Debit Card", "₹5,842.00", 10, WARNING_AMBER),
    ]
    ty = mid_y + 60 * scale
    f_t_name = get_font(FONT_SEMIBOLD, 11, scale)
    f_t_val = get_font(FONT_BOLD, 11, scale)
    for name, amt, pct, col in tenders:
        draw.text((split_x + 20 * scale, ty), name, fill=TEXT_MAIN, font=f_t_name)
        draw.text((split_x + split_w - 110 * scale, ty), amt, fill=TEXT_MAIN, font=f_t_val)
        ty += 22 * scale
        # Progress track
        draw.rounded_rectangle([split_x + 20 * scale, ty, split_x + split_w - 20 * scale, ty + 10 * scale], radius=5 * scale, fill=(241, 245, 249))
        bar_fill = int((pct / 100) * (split_w - 40 * scale))
        draw.rounded_rectangle([split_x + 20 * scale, ty, split_x + 20 * scale + bar_fill, ty + 10 * scale], radius=5 * scale, fill=col)
        ty += 28 * scale

    # Bottom Section: Live Synced Invoices Table
    table_y = mid_y + mid_h + 20 * scale
    table_h = (h * scale) - table_y - 24 * scale
    draw.rounded_rectangle([content_x, table_y, content_x + content_w, table_y + table_h], radius=10 * scale, fill=CARD_BG, outline=BORDER_COLOR, width=scale)
    
    draw.text((content_x + 20 * scale, table_y + 16 * scale), "Recent Counter Invoices (Live Reconciled Feed)", fill=TEXT_MAIN, font=f_ctitle)
    
    # Table Header Row
    th_y = table_y + 46 * scale
    draw.rectangle([content_x + 12 * scale, th_y, content_x + content_w - 12 * scale, th_y + 32 * scale], fill=(248, 250, 252))
    cols = [("INVOICE #", 120), ("TIME", 80), ("CASHIER", 140), ("ITEMS", 80), ("PAYMENT", 120), ("TOTAL", 100), ("STATUS", 100)]
    cx = content_x + 24 * scale
    f_th = get_font(FONT_BOLD, 9, scale)
    for cname, cwidth in cols:
        draw.text((cx, th_y + 9 * scale), cname, fill=TEXT_MUTED, font=f_th)
        cx += cwidth * scale
        
    rows = [
        ("INV-2026-0482", "18:42:15", "Terminal 1 (Rahul S.)", "6 items", "UPI QR", "₹485.50", "SYNCED"),
        ("INV-2026-0481", "18:39:04", "Terminal 2 (Priya M.)", "12 items", "Cash", "₹1,240.00", "SYNCED"),
        ("INV-2026-0480", "18:35:22", "Terminal 1 (Rahul S.)", "3 items", "UPI QR", "₹195.00", "SYNCED"),
        ("INV-2026-0479", "18:31:10", "Terminal 2 (Priya M.)", "8 items", "Card", "₹860.00", "SYNCED"),
    ]
    
    ry = th_y + 36 * scale
    f_tr = get_font(FONT_REGULAR, 11, scale)
    f_mono = get_font(FONT_MONO, 11, scale)
    f_badge = get_font(FONT_BOLD, 9, scale)
    
    for r in rows:
        cx = content_x + 24 * scale
        draw.text((cx, ry + 6 * scale), r[0], fill=PRIMARY_DARK, font=f_mono)
        cx += cols[0][1] * scale
        draw.text((cx, ry + 6 * scale), r[1], fill=TEXT_MUTED, font=f_tr)
        cx += cols[1][1] * scale
        draw.text((cx, ry + 6 * scale), r[2], fill=TEXT_MAIN, font=f_tr)
        cx += cols[2][1] * scale
        draw.text((cx, ry + 6 * scale), r[3], fill=TEXT_MUTED, font=f_tr)
        cx += cols[3][1] * scale
        draw.text((cx, ry + 6 * scale), r[4], fill=TEXT_MAIN, font=f_tr)
        cx += cols[4][1] * scale
        draw.text((cx, ry + 6 * scale), r[5], fill=TEXT_MAIN, font=f_mono)
        cx += cols[5][1] * scale
        # Status badge
        draw.rounded_rectangle([cx, ry + 4 * scale, cx + 64 * scale, ry + 22 * scale], radius=4 * scale, fill=SUCCESS_BG)
        draw.text((cx + 10 * scale, ry + 6 * scale), r[6], fill=SUCCESS_EMERALD, font=f_badge)
        
        draw.line([content_x + 12 * scale, ry + 32 * scale, content_x + content_w - 12 * scale, ry + 32 * scale], fill=(241, 245, 249), width=scale)
        ry += 36 * scale

    # Resize cleanly to 1440x900
    im_final = im.resize((w, h), Image.Resampling.LANCZOS)
    im_final.save(os.path.join(OUTPUT_DIR, "desktop-dashboard.png"), "PNG", optimize=True)
    print("Generated desktop-dashboard.png")

def generate_catalog():
    scale = 2
    w, h = 1440, 900
    im = Image.new("RGB", (w * scale, h * scale), BG_DESKTOP)
    draw = ImageDraw.Draw(im)
    
    draw_window_chrome(draw, w * scale, h * scale, scale=scale)
    sb_w = draw_sidebar(draw, scale=scale, active_index=2, w=w, h=h)
    
    content_x = sb_w + 28 * scale
    content_w = (w * scale) - content_x - 28 * scale
    header_y = 62 * scale
    
    f_h1 = get_font(FONT_BOLD, 20, scale)
    f_h_sub = get_font(FONT_REGULAR, 11, scale)
    draw.text((content_x, header_y), "Product & Category Catalog", fill=TEXT_MAIN, font=f_h1)
    draw.text((content_x, header_y + 28 * scale), "Master SKU repository, grocery pack-size variants, thermal shelf labels & pricing tiers", fill=TEXT_MUTED, font=f_h_sub)
    
    # Top Action Buttons
    ax = content_x + content_w - 420 * scale
    f_btn = get_font(FONT_BOLD, 10, scale)
    # CSV Import
    draw.rounded_rectangle([ax, header_y + 6 * scale, ax + 110 * scale, header_y + 36 * scale], radius=6 * scale, fill=CARD_BG, outline=BORDER_COLOR, width=scale)
    draw.text((ax + 14 * scale, header_y + 14 * scale), "📥 Import CSV", fill=TEXT_MAIN, font=f_btn)
    ax += 120 * scale
    # Print Thermal Labels
    draw.rounded_rectangle([ax, header_y + 6 * scale, ax + 130 * scale, header_y + 36 * scale], radius=6 * scale, fill=CARD_BG, outline=BORDER_COLOR, width=scale)
    draw.text((ax + 14 * scale, header_y + 14 * scale), "🏷️ Shelf Labels", fill=TEXT_MAIN, font=f_btn)
    ax += 140 * scale
    # Add Product
    draw.rounded_rectangle([ax, header_y + 6 * scale, ax + 130 * scale, header_y + 36 * scale], radius=6 * scale, fill=PRIMARY_INDIGO)
    draw.text((ax + 16 * scale, header_y + 14 * scale), "+ Add Product", fill=(255, 255, 255), font=f_btn)

    # Search Bar & Filter Chips
    search_y = header_y + 62 * scale
    search_h = 42 * scale
    draw.rounded_rectangle([content_x, search_y, content_x + 380 * scale, search_y + search_h], radius=8 * scale, fill=CARD_BG, outline=BORDER_COLOR, width=scale)
    f_srch = get_font(FONT_REGULAR, 11, scale)
    draw.text((content_x + 16 * scale, search_y + 12 * scale), "🔍  Search by product name, SKU, or scan barcode...", fill=TEXT_LIGHT, font=f_srch)
    
    # Category Chips
    chips = ["All Items (142)", "Dairy & Breakfast (24)", "Grains & Flours (38)", "Oils & Spices (32)", "Produce (28)", "Beverages (20)"]
    cx = content_x + 400 * scale
    for i, c in enumerate(chips):
        is_sel = (i == 0)
        bg = PRIMARY_DARK if is_sel else CARD_BG
        fg = (255, 255, 255) if is_sel else TEXT_MUTED
        cw = len(c) * 8 * scale + 24 * scale
        draw.rounded_rectangle([cx, search_y, cx + cw, search_y + search_h], radius=20 * scale, fill=bg, outline=BORDER_COLOR, width=scale)
        draw.text((cx + 12 * scale, search_y + 13 * scale), c, fill=fg, font=f_btn)
        cx += cw + 10 * scale

    # Catalog Table Card
    table_y = search_y + search_h + 18 * scale
    table_h = (h * scale) - table_y - 24 * scale
    draw.rounded_rectangle([content_x, table_y, content_x + content_w, table_y + table_h], radius=10 * scale, fill=CARD_BG, outline=BORDER_COLOR, width=scale)
    
    # Table Header
    th_y = table_y + 12 * scale
    draw.rectangle([content_x + 12 * scale, th_y, content_x + content_w - 12 * scale, th_y + 36 * scale], fill=(248, 250, 252))
    cols = [("PRODUCT NAME & VARIANT", 260), ("BARCODE / SKU", 140), ("CATEGORY", 130), ("COST", 90), ("PRICE", 90), ("GST", 60), ("STOCK LEVEL", 130), ("ACTIONS", 90)]
    cx = content_x + 24 * scale
    f_th = get_font(FONT_BOLD, 9, scale)
    for cname, cwidth in cols:
        draw.text((cx, th_y + 11 * scale), cname, fill=TEXT_MUTED, font=f_th)
        cx += cwidth * scale
        
    items_data = [
        ("Amul Gold Full Cream Milk [500ml]", "8901262010012", "Dairy & Breakfast", "₹30.00", "₹33.00", "0%", 48, 10, "In Stock"),
        ("Amul Gold Full Cream Milk [1 Litre]", "8901262010029", "Dairy & Breakfast", "₹59.00", "₹64.00", "0%", 32, 10, "In Stock"),
        ("India Gate Basmati Rice Feast [1 kg]", "8901414000142", "Grains & Flours", "₹95.00", "₹120.00", "5%", 24, 8, "In Stock"),
        ("India Gate Basmati Rice Feast [5 kg]", "8901414000159", "Grains & Flours", "₹460.00", "₹550.00", "5%", 6, 8, "Low Stock"),
        ("Tata Salt Vacuum Evaporated [1 kg]", "8901030023410", "Spices & Pantry", "₹22.50", "₹28.00", "0%", 85, 15, "In Stock"),
        ("Fortune Sunlite Refined Oil [1 Litre]", "8906007280015", "Oils & Ghee", "₹122.00", "₹145.00", "5%", 14, 10, "In Stock"),
        ("Fortune Sunlite Refined Oil [5 Litre Jar]", "8906007280053", "Oils & Ghee", "₹610.00", "₹720.00", "5%", 2, 5, "Critical"),
        ("Aashirvaad Shudh Chakki Atta [5 kg]", "8901725181222", "Grains & Flours", "₹240.00", "₹285.00", "5%", 19, 10, "In Stock"),
        ("Nescafe Classic Instant Coffee [100g]", "8901058852214", "Beverages", "₹190.00", "₹235.00", "18%", 11, 10, "In Stock"),
        ("Tata Tea Premium Leaf [500g]", "8901052002103", "Beverages", "₹185.00", "₹230.00", "5%", 22, 10, "In Stock"),
    ]
    
    ry = th_y + 44 * scale
    f_name = get_font(FONT_SEMIBOLD, 11, scale)
    f_mono = get_font(FONT_MONO, 10, scale)
    f_cat = get_font(FONT_REGULAR, 10, scale)
    f_badge = get_font(FONT_BOLD, 8, scale)
    f_action = get_font(FONT_BOLD, 9, scale)
    
    for item in items_data:
        name, barcode, cat, cost, price, gst, stock, min_stock, status = item
        cx = content_x + 24 * scale
        
        # Name
        draw.text((cx, ry + 6 * scale), name, fill=TEXT_MAIN, font=f_name)
        cx += cols[0][1] * scale
        
        # Barcode
        draw.text((cx, ry + 6 * scale), barcode, fill=PRIMARY_DARK, font=f_mono)
        cx += cols[1][1] * scale
        
        # Category
        draw.text((cx, ry + 6 * scale), cat, fill=TEXT_MUTED, font=f_cat)
        cx += cols[2][1] * scale
        
        # Cost & Price
        draw.text((cx, ry + 6 * scale), cost, fill=TEXT_MUTED, font=f_mono)
        cx += cols[3][1] * scale
        draw.text((cx, ry + 6 * scale), price, fill=TEXT_MAIN, font=f_mono)
        cx += cols[4][1] * scale
        draw.text((cx, ry + 6 * scale), gst, fill=TEXT_MUTED, font=f_cat)
        cx += cols[5][1] * scale
        
        # Stock Level + Micro Progress Bar
        draw.text((cx, ry + 2 * scale), f"{stock} units", fill=TEXT_MAIN, font=f_name)
        draw.rounded_rectangle([cx, ry + 18 * scale, cx + 80 * scale, ry + 23 * scale], radius=3 * scale, fill=(241, 245, 249))
        fill_pct = min(1.0, stock / (min_stock * 3))
        bar_col = SUCCESS_EMERALD if stock > min_stock else (WARNING_AMBER if stock > 2 else DANGER_ROSE)
        draw.rounded_rectangle([cx, ry + 18 * scale, cx + int(80 * scale * fill_pct), ry + 23 * scale], radius=3 * scale, fill=bar_col)
        cx += cols[6][1] * scale
        
        # Action Edit / Print
        draw.rounded_rectangle([cx, ry + 4 * scale, cx + 44 * scale, ry + 24 * scale], radius=4 * scale, fill=(241, 245, 249))
        draw.text((cx + 10 * scale, ry + 6 * scale), "Edit", fill=PRIMARY_INDIGO, font=f_action)
        draw.rounded_rectangle([cx + 50 * scale, ry + 4 * scale, cx + 76 * scale, ry + 24 * scale], radius=4 * scale, fill=(241, 245, 249))
        draw.text((cx + 56 * scale, ry + 6 * scale), "🏷️", fill=TEXT_MAIN, font=f_badge)
        
        draw.line([content_x + 12 * scale, ry + 32 * scale, content_x + content_w - 12 * scale, ry + 32 * scale], fill=(241, 245, 249), width=scale)
        ry += 36 * scale

    im_final = im.resize((w, h), Image.Resampling.LANCZOS)
    im_final.save(os.path.join(OUTPUT_DIR, "desktop-catalog.png"), "PNG", optimize=True)
    print("Generated desktop-catalog.png")

def generate_low_stock():
    scale = 2
    w, h = 1440, 900
    im = Image.new("RGB", (w * scale, h * scale), BG_DESKTOP)
    draw = ImageDraw.Draw(im)
    
    draw_window_chrome(draw, w * scale, h * scale, scale=scale)
    sb_w = draw_sidebar(draw, scale=scale, active_index=3, w=w, h=h)
    
    content_x = sb_w + 28 * scale
    content_w = (w * scale) - content_x - 28 * scale
    header_y = 62 * scale
    
    f_h1 = get_font(FONT_BOLD, 20, scale)
    f_h_sub = get_font(FONT_REGULAR, 11, scale)
    draw.text((content_x, header_y), "Low Stock & Replenishment Console", fill=TEXT_MAIN, font=f_h1)
    draw.text((content_x, header_y + 28 * scale), "Real-time depletion tracking, dynamic safety stock thresholds, and 1-click supplier restocking", fill=TEXT_MUTED, font=f_h_sub)
    
    # Export CSV Button
    ax = content_x + content_w - 220 * scale
    f_btn = get_font(FONT_BOLD, 10, scale)
    draw.rounded_rectangle([ax, header_y + 6 * scale, ax + 200 * scale, header_y + 36 * scale], radius=6 * scale, fill=CARD_BG, outline=BORDER_COLOR, width=scale)
    draw.text((ax + 16 * scale, header_y + 14 * scale), "📑 Export Reorder Sheet (CSV)", fill=TEXT_MAIN, font=f_btn)

    # 4 KPI Alert Cards
    kpi_y = header_y + 62 * scale
    gap = 16 * scale
    card_w = (content_w - 3 * gap) // 4
    card_h = 108 * scale
    
    draw_kpi_card(draw, content_x + 0 * (card_w + gap), kpi_y, card_w, card_h, "OUT OF STOCK ITEMS", "3 SKUs", "Immediate replenishment needed", "CRITICAL", "🚫", scale, DANGER_ROSE)
    draw_kpi_card(draw, content_x + 1 * (card_w + gap), kpi_y, card_w, card_h, "CRITICAL STOCK LEVEL", "5 SKUs", "<= 2 units remaining", "DEFICIT", "⚠️", scale, ORANGE_EXPIRY)
    draw_kpi_card(draw, content_x + 2 * (card_w + gap), kpi_y, card_w, card_h, "TOTAL LOW STOCK ITEMS", "12 SKUs", "Below minimum alert threshold", "WATCHLIST", "📦", scale, WARNING_AMBER)
    draw_kpi_card(draw, content_x + 3 * (card_w + gap), kpi_y, card_w, card_h, "EST. REORDER CAPITAL", "₹18,450.00", "To restore target safety stock", "OPTIMAL", "💵", scale, PRIMARY_INDIGO)

    # Table Card
    table_y = kpi_y + card_h + 20 * scale
    table_h = (h * scale) - table_y - 24 * scale
    draw.rounded_rectangle([content_x, table_y, content_x + content_w, table_y + table_h], radius=10 * scale, fill=CARD_BG, outline=BORDER_COLOR, width=scale)
    
    # Filter Tabs inside table header
    th_y = table_y + 14 * scale
    f_tab = get_font(FONT_BOLD, 10, scale)
    tabs = ["All Low Stock (12)", "Out of Stock (3)", "Critical Stock (5)"]
    tx = content_x + 20 * scale
    for i, t in enumerate(tabs):
        is_sel = (i == 0)
        bg = PRIMARY_INDIGO if is_sel else (241, 245, 249)
        fg = (255, 255, 255) if is_sel else TEXT_MUTED
        tw = len(t) * 8 * scale + 20 * scale
        draw.rounded_rectangle([tx, th_y, tx + tw, th_y + 28 * scale], radius=6 * scale, fill=bg)
        draw.text((tx + 10 * scale, th_y + 6 * scale), t, fill=fg, font=f_tab)
        tx += tw + 10 * scale

    # Table Header
    thead_y = th_y + 42 * scale
    draw.rectangle([content_x + 12 * scale, thead_y, content_x + content_w - 12 * scale, thead_y + 36 * scale], fill=(248, 250, 252))
    cols = [("HEALTH STATUS", 140), ("PRODUCT & SKU", 260), ("CURRENT", 90), ("MIN ALERT", 90), ("DEFICIT GAUGE", 140), ("SUGGESTED REORDER", 150), ("ACTION", 100)]
    cx = content_x + 24 * scale
    f_th = get_font(FONT_BOLD, 9, scale)
    for cname, cwidth in cols:
        draw.text((cx, thead_y + 11 * scale), cname, fill=TEXT_MUTED, font=f_th)
        cx += cwidth * scale
        
    low_stock_data = [
        ("OUT OF STOCK", DANGER_BG, DANGER_ROSE, "Fortune Refined Oil [5L Jar]", "8906007280053", 0, 8, 8, "₹4,880.00"),
        ("OUT OF STOCK", DANGER_BG, DANGER_ROSE, "Tata Salt Vacuum [1kg]", "8901030023410", 0, 20, 20, "₹450.00"),
        ("OUT OF STOCK", DANGER_BG, DANGER_ROSE, "Dairy Fresh Butter [500g]", "8901233020011", 0, 10, 10, "₹2,400.00"),
        ("CRITICAL", ORANGE_BG, ORANGE_EXPIRY, "India Gate Basmati Rice [5kg]", "8901414000159", 1, 10, 9, "₹4,140.00"),
        ("CRITICAL", ORANGE_BG, ORANGE_EXPIRY, "Maggi 2-Minute Noodles [70g]", "8901058852331", 2, 24, 22, "₹264.00"),
        ("CRITICAL", ORANGE_BG, ORANGE_EXPIRY, "Dettol Antiseptic Liquid [500ml]", "8901396001102", 2, 12, 10, "₹1,850.00"),
        ("LOW STOCK", WARNING_BG, WARNING_AMBER, "Aashirvaad Whole Wheat Atta [5kg]", "8901725181222", 4, 15, 11, "₹2,640.00"),
        ("LOW STOCK", WARNING_BG, WARNING_AMBER, "Surf Excel Easy Wash [1kg]", "8901030381015", 5, 15, 10, "₹1,320.00"),
        ("LOW STOCK", WARNING_BG, WARNING_AMBER, "Red Label Tea [500g]", "8901030023412", 6, 12, 6, "₹1,260.00"),
    ]
    
    ry = thead_y + 44 * scale
    f_badge = get_font(FONT_BOLD, 8, scale)
    f_name = get_font(FONT_SEMIBOLD, 11, scale)
    f_sku = get_font(FONT_MONO, 9, scale)
    f_qty = get_font(FONT_BOLD, 11, scale)
    f_reorder = get_font(FONT_SEMIBOLD, 10, scale)
    f_action = get_font(FONT_BOLD, 9, scale)
    
    for row in low_stock_data:
        badge_txt, b_bg, b_fg, name, sku, cur, m_alert, reorder, cost = row
        cx = content_x + 24 * scale
        
        # Health Badge
        draw.rounded_rectangle([cx, ry + 4 * scale, cx + 96 * scale, ry + 24 * scale], radius=4 * scale, fill=b_bg)
        draw.text((cx + 8 * scale, ry + 6 * scale), badge_txt, fill=b_fg, font=f_badge)
        cx += cols[0][1] * scale
        
        # Product & SKU
        draw.text((cx, ry + 2 * scale), name, fill=TEXT_MAIN, font=f_name)
        draw.text((cx, ry + 18 * scale), sku, fill=TEXT_LIGHT, font=f_sku)
        cx += cols[1][1] * scale
        
        # Current Stock
        draw.text((cx, ry + 6 * scale), f"{cur} units", fill=b_fg, font=f_qty)
        cx += cols[2][1] * scale
        
        # Min Alert
        draw.text((cx, ry + 6 * scale), f"{m_alert} units", fill=TEXT_MUTED, font=f_qty)
        cx += cols[3][1] * scale
        
        # Gauge
        draw.rounded_rectangle([cx, ry + 12 * scale, cx + 100 * scale, ry + 18 * scale], radius=3 * scale, fill=(241, 245, 249))
        fill_w = int((cur / max(1, m_alert)) * 100 * scale)
        if fill_w > 0:
            draw.rounded_rectangle([cx, ry + 12 * scale, cx + fill_w, ry + 18 * scale], radius=3 * scale, fill=b_fg)
        cx += cols[4][1] * scale
        
        # Suggested Reorder
        draw.text((cx, ry + 2 * scale), f"+{reorder} units", fill=PRIMARY_DARK, font=f_qty)
        draw.text((cx, ry + 18 * scale), f"Est: {cost}", fill=TEXT_MUTED, font=f_reorder)
        cx += cols[5][1] * scale
        
        # 1-Click Restock Button
        draw.rounded_rectangle([cx, ry + 4 * scale, cx + 78 * scale, ry + 26 * scale], radius=5 * scale, fill=PRIMARY_INDIGO)
        draw.text((cx + 12 * scale, ry + 8 * scale), "+ Restock", fill=(255, 255, 255), font=f_action)
        
        draw.line([content_x + 12 * scale, ry + 36 * scale, content_x + content_w - 12 * scale, ry + 36 * scale], fill=(241, 245, 249), width=scale)
        ry += 40 * scale

    # Modal Overlay: Quick Restock Popover (showing Emil-style micro interaction)
    mx = content_x + content_w - 360 * scale
    my = thead_y + 110 * scale
    mw = 340 * scale
    mh = 230 * scale
    
    # Shadow & Card
    draw.rounded_rectangle([mx - 2 * scale, my - 2 * scale, mx + mw + 2 * scale, my + mh + 2 * scale], radius=12 * scale, fill=(15, 23, 42, 30))
    draw.rounded_rectangle([mx, my, mx + mw, my + mh], radius=10 * scale, fill=CARD_BG, outline=PRIMARY_INDIGO, width=2 * scale)
    
    f_m_title = get_font(FONT_BOLD, 12, scale)
    f_m_sub = get_font(FONT_REGULAR, 9, scale)
    draw.text((mx + 16 * scale, my + 14 * scale), "⚡ Quick Restock: Tata Salt 1kg", fill=TEXT_MAIN, font=f_m_title)
    draw.text((mx + 16 * scale, my + 32 * scale), "Current: 0 units • Min threshold: 20 units", fill=TEXT_MUTED, font=f_m_sub)
    
    # Preset chips
    draw.text((mx + 16 * scale, my + 54 * scale), "SELECT QUANTITY PRESET:", fill=TEXT_LIGHT, font=f_badge)
    presets = ["+5", "+10", "+25", "+50", "+100"]
    px = mx + 16 * scale
    for i, p in enumerate(presets):
        is_sel = (i == 2)  # +25
        bg = PRIMARY_DARK if is_sel else (241, 245, 249)
        fg = (255, 255, 255) if is_sel else TEXT_MAIN
        draw.rounded_rectangle([px, my + 70 * scale, px + 52 * scale, my + 98 * scale], radius=6 * scale, fill=bg)
        draw.text((px + 12 * scale, my + 78 * scale), p, fill=fg, font=f_action)
        px += 60 * scale
        
    # Cost & Vendor
    draw.text((mx + 16 * scale, my + 116 * scale), "Cost Price: ₹22.50 / unit  •  Total Inflow: ₹562.50", fill=TEXT_MAIN, font=f_name)
    draw.text((mx + 16 * scale, my + 136 * scale), "Audit Reason: 'Standard Distributor Shipment'", fill=TEXT_MUTED, font=f_m_sub)
    
    # Commit Button
    draw.rounded_rectangle([mx + 16 * scale, my + 168 * scale, mx + mw - 16 * scale, my + 208 * scale], radius=6 * scale, fill=SUCCESS_EMERALD)
    draw.text((mx + 70 * scale, my + 180 * scale), "✓ Commit Restock & Log Inflow", fill=(255, 255, 255), font=f_btn)

    im_final = im.resize((w, h), Image.Resampling.LANCZOS)
    im_final.save(os.path.join(OUTPUT_DIR, "desktop-low-stock-replenishment.png"), "PNG", optimize=True)
    print("Generated desktop-low-stock-replenishment.png")

def generate_expiry_tracker():
    scale = 2
    w, h = 1440, 900
    im = Image.new("RGB", (w * scale, h * scale), BG_DESKTOP)
    draw = ImageDraw.Draw(im)
    
    draw_window_chrome(draw, w * scale, h * scale, scale=scale)
    sb_w = draw_sidebar(draw, scale=scale, active_index=4, w=w, h=h)
    
    content_x = sb_w + 28 * scale
    content_w = (w * scale) - content_x - 28 * scale
    header_y = 62 * scale
    
    f_h1 = get_font(FONT_BOLD, 20, scale)
    f_h_sub = get_font(FONT_REGULAR, 11, scale)
    draw.text((content_x, header_y), "Perishables & Expiry Management Tracker", fill=TEXT_MAIN, font=f_h1)
    draw.text((content_x, header_y + 28 * scale), "Monitor batch shelf-life, trigger rapid clearance markdowns, and write off expired grocery inventory", fill=TEXT_MUTED, font=f_h_sub)
    
    # Export Pull Sheet Button
    ax = content_x + content_w - 220 * scale
    f_btn = get_font(FONT_BOLD, 10, scale)
    draw.rounded_rectangle([ax, header_y + 6 * scale, ax + 200 * scale, header_y + 36 * scale], radius=6 * scale, fill=CARD_BG, outline=BORDER_COLOR, width=scale)
    draw.text((ax + 16 * scale, header_y + 14 * scale), "📋 Export Pull-Sheet (CSV)", fill=TEXT_MAIN, font=f_btn)

    # 4 KPI Alert Cards
    kpi_y = header_y + 62 * scale
    gap = 16 * scale
    card_w = (content_w - 3 * gap) // 4
    card_h = 108 * scale
    
    draw_kpi_card(draw, content_x + 0 * (card_w + gap), kpi_y, card_w, card_h, "EXPIRED PRODUCTS", "2 SKUs", "Immediate shelf pull required", "ACTION REQUIRED", "🚫", scale, DANGER_ROSE)
    draw_kpi_card(draw, content_x + 1 * (card_w + gap), kpi_y, card_w, card_h, "EXPIRING IN 7 DAYS", "4 SKUs", "Trigger markdown promotions", "URGENT", "⏰", scale, ORANGE_EXPIRY)
    draw_kpi_card(draw, content_x + 2 * (card_w + gap), kpi_y, card_w, card_h, "EXPIRING IN 30 DAYS", "9 SKUs", "Watchlist for FIFO rotation", "PLANNED", "📅", scale, WARNING_AMBER)
    draw_kpi_card(draw, content_x + 3 * (card_w + gap), kpi_y, card_w, card_h, "PERISHABLES TRACKED", "38 Batches", "With active lot numbers", "ACTIVE", "🥛", scale, SUCCESS_EMERALD)

    # Table Card
    table_y = kpi_y + card_h + 20 * scale
    table_h = (h * scale) - table_y - 24 * scale
    draw.rounded_rectangle([content_x, table_y, content_x + content_w, table_y + table_h], radius=10 * scale, fill=CARD_BG, outline=BORDER_COLOR, width=scale)
    
    # Table Header
    th_y = table_y + 14 * scale
    draw.rectangle([content_x + 12 * scale, th_y, content_x + content_w - 12 * scale, th_y + 36 * scale], fill=(248, 250, 252))
    cols = [("URGENCY STATUS", 150), ("PRODUCT & BATCH #", 260), ("EXPIRY DATE", 120), ("STOCK", 90), ("ORIGINAL", 80), ("CLEARANCE PRICE", 130), ("ACTION", 130)]
    cx = content_x + 24 * scale
    f_th = get_font(FONT_BOLD, 9, scale)
    for cname, cwidth in cols:
        draw.text((cx, th_y + 11 * scale), cname, fill=TEXT_MUTED, font=f_th)
        cx += cwidth * scale
        
    expiry_data = [
        ("EXPIRED (2d AGO)", DANGER_BG, DANGER_ROSE, "Dairy Life Whole Milk [500ml]", "BATCH: LOT-2026-M11", "04 Nov 2026", "4 units", "₹33.00", "BLOCKED AT SCAN", "Write-Off Waste"),
        ("EXPIRED (1d AGO)", DANGER_BG, DANGER_ROSE, "Organic Greek Yogurt [200g]", "BATCH: LOT-2026-Y09", "05 Nov 2026", "6 units", "₹75.00", "BLOCKED AT SCAN", "Write-Off Waste"),
        ("EXPIRES TODAY", ORANGE_BG, ORANGE_EXPIRY, "Baker's Choice White Bread [400g]", "BATCH: LOT-2026-B88", "06 Nov 2026", "8 units", "₹45.00", "₹22.50 (-50%)", "Markdown Sale"),
        ("EXPIRES IN 2 DAYS", ORANGE_BG, ORANGE_EXPIRY, "Farm Fresh Paneer [200g]", "BATCH: LOT-2026-P44", "08 Nov 2026", "14 units", "₹90.00", "₹63.00 (-30%)", "Markdown Sale"),
        ("EXPIRES IN 5 DAYS", WARNING_BG, WARNING_AMBER, "Fresh Spiced Buttermilk [200ml]", "BATCH: LOT-2026-BM1", "11 Nov 2026", "22 units", "₹18.00", "₹14.40 (-20%)", "Markdown Sale"),
        ("18 DAYS LEFT", (241, 245, 249), TEXT_MUTED, "Amul Salted Butter [100g]", "BATCH: LOT-2026-BT8", "24 Nov 2026", "35 units", "₹56.00", "₹56.00 (Standard)", "Inspect Batch"),
        ("24 DAYS LEFT", (241, 245, 249), TEXT_MUTED, "Harvest Gold Brown Bread", "BATCH: LOT-2026-BR2", "30 Nov 2026", "18 units", "₹50.00", "₹50.00 (Standard)", "Inspect Batch"),
    ]
    
    ry = th_y + 44 * scale
    f_badge = get_font(FONT_BOLD, 8, scale)
    f_name = get_font(FONT_SEMIBOLD, 11, scale)
    f_sku = get_font(FONT_MONO, 9, scale)
    f_qty = get_font(FONT_REGULAR, 10, scale)
    f_price = get_font(FONT_BOLD, 10, scale)
    f_action = get_font(FONT_BOLD, 9, scale)
    
    for row in expiry_data:
        badge_txt, b_bg, b_fg, name, batch, exp_date, stock, orig_p, clear_p, act_txt = row
        cx = content_x + 24 * scale
        
        # Badge
        draw.rounded_rectangle([cx, ry + 4 * scale, cx + 115 * scale, ry + 24 * scale], radius=4 * scale, fill=b_bg)
        draw.text((cx + 8 * scale, ry + 6 * scale), badge_txt, fill=b_fg, font=f_badge)
        cx += cols[0][1] * scale
        
        # Name & Batch
        draw.text((cx, ry + 2 * scale), name, fill=TEXT_MAIN, font=f_name)
        draw.text((cx, ry + 18 * scale), batch, fill=TEXT_LIGHT, font=f_sku)
        cx += cols[1][1] * scale
        
        # Expiry date
        draw.text((cx, ry + 6 * scale), exp_date, fill=b_fg if "EXPIRED" in badge_txt else TEXT_MAIN, font=f_name)
        cx += cols[2][1] * scale
        
        # Stock
        draw.text((cx, ry + 6 * scale), stock, fill=TEXT_MAIN, font=f_qty)
        cx += cols[3][1] * scale
        
        # Original price
        draw.text((cx, ry + 6 * scale), orig_p, fill=TEXT_MUTED, font=f_qty)
        cx += cols[4][1] * scale
        
        # Clearance price
        c_col = DANGER_ROSE if "BLOCKED" in clear_p else (SUCCESS_EMERALD if "-" in clear_p else TEXT_MAIN)
        draw.text((cx, ry + 6 * scale), clear_p, fill=c_col, font=f_price)
        cx += cols[5][1] * scale
        
        # Action button
        act_bg = DANGER_ROSE if "Write-Off" in act_txt else (WARNING_AMBER if "Markdown" in act_txt else (241, 245, 249))
        act_fg = (255, 255, 255) if "Inspect" not in act_txt else TEXT_MAIN
        draw.rounded_rectangle([cx, ry + 4 * scale, cx + 104 * scale, ry + 26 * scale], radius=5 * scale, fill=act_bg)
        draw.text((cx + 8 * scale, ry + 8 * scale), act_txt, fill=act_fg, font=f_action)
        
        draw.line([content_x + 12 * scale, ry + 36 * scale, content_x + content_w - 12 * scale, ry + 36 * scale], fill=(241, 245, 249), width=scale)
        ry += 40 * scale

    # Modal: Clearance Markdown Dialog
    mx = content_x + content_w - 380 * scale
    my = th_y + 130 * scale
    mw = 360 * scale
    mh = 240 * scale
    
    draw.rounded_rectangle([mx - 2 * scale, my - 2 * scale, mx + mw + 2 * scale, my + mh + 2 * scale], radius=12 * scale, fill=(15, 23, 42, 30))
    draw.rounded_rectangle([mx, my, mx + mw, my + mh], radius=10 * scale, fill=CARD_BG, outline=WARNING_AMBER, width=2 * scale)
    
    f_m_title = get_font(FONT_BOLD, 12, scale)
    f_m_sub = get_font(FONT_REGULAR, 9, scale)
    draw.text((mx + 16 * scale, my + 14 * scale), "⚡ Rapid Clearance Markdown", fill=TEXT_MAIN, font=f_m_title)
    draw.text((mx + 16 * scale, my + 32 * scale), "Baker's Choice Bread • Expires in 24 hours", fill=TEXT_MUTED, font=f_m_sub)
    
    # Discount presets
    draw.text((mx + 16 * scale, my + 54 * scale), "APPLY FAST DISCOUNT PRESET:", fill=TEXT_LIGHT, font=f_badge)
    discounts = ["-10%", "-20%", "-30%", "-50%", "Clearance ₹20"]
    px = mx + 16 * scale
    for i, d in enumerate(discounts):
        is_sel = (i == 3)  # -50%
        bg = WARNING_AMBER if is_sel else (241, 245, 249)
        fg = (255, 255, 255) if is_sel else TEXT_MAIN
        dw = 58 * scale if i < 4 else 86 * scale
        draw.rounded_rectangle([px, my + 70 * scale, px + dw, my + 98 * scale], radius=6 * scale, fill=bg)
        draw.text((px + 8 * scale, my + 78 * scale), d, fill=fg, font=f_action)
        px += dw + 8 * scale
        
    draw.text((mx + 16 * scale, my + 116 * scale), "Original Price: ₹45.00  ➔  Discounted Price: ₹22.50", fill=SUCCESS_EMERALD, font=f_name)
    draw.text((mx + 16 * scale, my + 138 * scale), "Sync to 2 Cashier Terminals instantly via WebSocket/HTTP", fill=TEXT_MUTED, font=f_m_sub)
    
    draw.rounded_rectangle([mx + 16 * scale, my + 172 * scale, mx + mw - 16 * scale, my + 214 * scale], radius=6 * scale, fill=PRIMARY_INDIGO)
    draw.text((mx + 60 * scale, my + 184 * scale), "✓ Broadcast Clearance Price Now", fill=(255, 255, 255), font=f_btn)

    im_final = im.resize((w, h), Image.Resampling.LANCZOS)
    im_final.save(os.path.join(OUTPUT_DIR, "desktop-expiry-tracker.png"), "PNG", optimize=True)
    print("Generated desktop-expiry-tracker.png")

def draw_phone_frame(draw, x, y, pw, ph, scale=2):
    """Draws realistic smartphone body with rounded corners, bezel, and dynamic island."""
    # Outer titanium bezel
    draw.rounded_rectangle([x, y, x + pw, y + ph], radius=38 * scale, fill=(24, 24, 27), outline=(63, 63, 70), width=4 * scale)
    # Inner display screen
    sx = x + 10 * scale
    sy = y + 10 * scale
    sw = pw - 20 * scale
    sh = ph - 20 * scale
    draw.rounded_rectangle([sx, sy, sx + sw, sy + sh], radius=30 * scale, fill=(15, 23, 42))
    
    # Dynamic island / punch hole notch
    nx = x + (pw // 2) - 40 * scale
    ny = sy + 8 * scale
    draw.rounded_rectangle([nx, ny, nx + 80 * scale, ny + 18 * scale], radius=9 * scale, fill=(0, 0, 0))
    # Camera sensor dot
    draw.ellipse([nx + 58 * scale, ny + 5 * scale, nx + 66 * scale, ny + 13 * scale], fill=(30, 41, 59))
    
    # Status bar
    f_stat = get_font(FONT_SEMIBOLD, 9, scale)
    draw.text((sx + 18 * scale, sy + 10 * scale), "09:41", fill=(255, 255, 255), font=f_stat)
    draw.text((sx + sw - 64 * scale, sy + 10 * scale), "5G  📶 98%", fill=(255, 255, 255), font=f_stat)
    
    # Home indicator bar at bottom
    hx = x + (pw // 2) - 50 * scale
    hy = y + ph - 16 * scale
    draw.rounded_rectangle([hx, hy, hx + 100 * scale, hy + 4 * scale], radius=2 * scale, fill=(148, 163, 184))

    return sx, sy + 32 * scale, sw, sh - 42 * scale

def generate_mobile_suite():
    scale = 2
    w, h = 1440, 900
    im = Image.new("RGB", (w * scale, h * scale), (241, 245, 249))
    draw = ImageDraw.Draw(im)
    
    # Header on background
    f_title = get_font(FONT_BOLD, 22, scale)
    f_sub = get_font(FONT_REGULAR, 12, scale)
    draw.text((60 * scale, 40 * scale), "Android Cashier Suite — High-Speed Retail Workflow", fill=TEXT_MAIN, font=f_title)
    draw.text((60 * scale, 72 * scale), "Hardware ToneGenerator (2048Hz) barcode laser scanning, zero-drift decimal cart, and thermal printing", fill=TEXT_MUTED, font=f_sub)
    
    # Dual Phone dimensions
    phone_w = 360 * scale
    phone_h = 740 * scale
    
    # ------------------ LEFT PHONE: BARCODE SCANNER HUD ------------------
    p1_x = 180 * scale
    p1_y = 115 * scale
    sx1, sy1, sw1, sh1 = draw_phone_frame(draw, p1_x, p1_y, phone_w, phone_h, scale)
    
    # Phone 1 App Header
    draw.rectangle([sx1, sy1, sx1 + sw1, sy1 + 54 * scale], fill=(30, 41, 59))
    f_app = get_font(FONT_BOLD, 12, scale)
    f_reg = get_font(FONT_REGULAR, 9, scale)
    draw.text((sx1 + 16 * scale, sy1 + 10 * scale), "WebotApp POS Terminal #1", fill=(255, 255, 255), font=f_app)
    draw.text((sx1 + 16 * scale, sy1 + 28 * scale), "Cashier: Rahul Sharma", fill=SIDEBAR_TEXT, font=f_reg)
    
    # Sync status pill in header
    f_pill = get_font(FONT_BOLD, 8, scale)
    draw.rounded_rectangle([sx1 + sw1 - 85 * scale, sy1 + 14 * scale, sx1 + sw1 - 12 * scale, sy1 + 36 * scale], radius=11 * scale, fill=SUCCESS_BG)
    draw.text((sx1 + sw1 - 76 * scale, sy1 + 18 * scale), "🟢 SYNCED", fill=SUCCESS_EMERALD, font=f_pill)

    # Scanner Viewfinder Canvas (Simulated Camera Feed)
    vf_y = sy1 + 54 * scale
    vf_h = 320 * scale
    draw.rectangle([sx1, vf_y, sx1 + sw1, vf_y + vf_h], fill=(15, 23, 42))
    
    # Reticle / Viewfinder corners
    rw = 220 * scale
    rh = 160 * scale
    rx = sx1 + (sw1 - rw) // 2
    ry = vf_y + (vf_h - rh) // 2
    
    c_len = 24 * scale
    c_thick = 4 * scale
    # Top Left
    draw.line([rx, ry, rx + c_len, ry], fill=SUCCESS_EMERALD, width=c_thick)
    draw.line([rx, ry, rx, ry + c_len], fill=SUCCESS_EMERALD, width=c_thick)
    # Top Right
    draw.line([rx + rw, ry, rx + rw - c_len, ry], fill=SUCCESS_EMERALD, width=c_thick)
    draw.line([rx + rw, ry, rx + rw, ry + c_len], fill=SUCCESS_EMERALD, width=c_thick)
    # Bottom Left
    draw.line([rx, ry + rh, rx + c_len, ry + rh], fill=SUCCESS_EMERALD, width=c_thick)
    draw.line([rx, ry + rh, rx, ry + rh - c_len], fill=SUCCESS_EMERALD, width=c_thick)
    # Bottom Right
    draw.line([rx + rw, ry + rh, rx + rw - c_len, ry + rh], fill=SUCCESS_EMERALD, width=c_thick)
    draw.line([rx + rw, ry + rh, rx + rw, ry + rh - c_len], fill=SUCCESS_EMERALD, width=c_thick)

    # Laser targeting line across center
    laser_y = ry + rh // 2
    draw.line([rx + 10 * scale, laser_y, rx + rw - 10 * scale, laser_y], fill=(239, 68, 68), width=2 * scale)

    # Simulated Scanned Barcode Graphic in Viewfinder
    f_code = get_font(FONT_MONO, 8, scale)
    draw.text((rx + 42 * scale, ry + rh - 22 * scale), "8901262010012", fill=(255, 255, 255), font=f_code)
    
    # Flash & Keyboard shortcut buttons inside viewfinder
    draw.ellipse([sx1 + 16 * scale, vf_y + 16 * scale, sx1 + 44 * scale, vf_y + 44 * scale], fill=(30, 41, 59, 180), outline=(255, 255, 255), width=scale)
    draw.text((sx1 + 22 * scale, vf_y + 20 * scale), "⚡", fill=(255, 255, 255), font=f_app)

    # Scan Confirmation HUD Toast (Emil Kowalski feedback principle)
    toast_y = vf_y + vf_h - 48 * scale
    draw.rounded_rectangle([sx1 + 16 * scale, toast_y, sx1 + sw1 - 16 * scale, toast_y + 36 * scale], radius=6 * scale, fill=(16, 185, 129))
    draw.text((sx1 + 26 * scale, toast_y + 8 * scale), "✓ 2048Hz Chirp • Amul Gold Milk 500ml added (₹33)", fill=(255, 255, 255), font=f_pill)

    # Scanned Recent Cart Summary Tray
    tray_y = vf_y + vf_h
    tray_h = sh1 - (tray_y - sy1)
    draw.rectangle([sx1, tray_y, sx1 + sw1, sy1 + sh1], fill=(255, 255, 255))
    
    # Cart items list preview
    draw.text((sx1 + 16 * scale, tray_y + 12 * scale), "CURRENT CART (4 ITEMS)", fill=TEXT_MUTED, font=f_pill)
    
    mini_items = [
        ("Amul Gold Full Cream Milk [500ml]", "1x", "₹33.00"),
        ("Tata Salt Vacuum Evaporated [1kg]", "2x", "₹56.00"),
        ("India Gate Basmati Rice [1kg]", "1x", "₹120.00"),
    ]
    my = tray_y + 32 * scale
    f_m_item = get_font(FONT_SEMIBOLD, 10, scale)
    f_m_mono = get_font(FONT_MONO, 10, scale)
    for m_name, m_qty, m_pr in mini_items:
        draw.text((sx1 + 16 * scale, my), m_name[:26] + "..", fill=TEXT_MAIN, font=f_m_item)
        draw.text((sx1 + sw1 - 110 * scale, my), m_qty, fill=TEXT_MUTED, font=f_m_mono)
        draw.text((sx1 + sw1 - 70 * scale, my), m_pr, fill=TEXT_MAIN, font=f_m_mono)
        my += 24 * scale

    # Big Sticky Checkout Bar at bottom of phone 1
    chk_y = sy1 + sh1 - 64 * scale
    draw.rounded_rectangle([sx1 + 12 * scale, chk_y, sx1 + sw1 - 12 * scale, chk_y + 50 * scale], radius=8 * scale, fill=PRIMARY_INDIGO)
    f_chk_txt = get_font(FONT_BOLD, 12, scale)
    f_chk_amt = get_font(FONT_BOLD, 14, scale)
    draw.text((sx1 + 24 * scale, chk_y + 14 * scale), "VIEW CART & BILL ➔", fill=(255, 255, 255), font=f_chk_txt)
    draw.text((sx1 + sw1 - 100 * scale, chk_y + 12 * scale), "₹209.00", fill=(255, 255, 255), font=f_chk_amt)

    # ------------------ RIGHT PHONE: REAL-TIME CART & DIGITAL RECEIPT ------------------
    p2_x = 740 * scale
    p2_y = 115 * scale
    sx2, sy2, sw2, sh2 = draw_phone_frame(draw, p2_x, p2_y, phone_w, phone_h, scale)
    
    # Phone 2 Screen Background
    draw.rectangle([sx2, sy2, sx2 + sw2, sy2 + sh2], fill=BG_DESKTOP)
    
    # Phone 2 App Header
    draw.rectangle([sx2, sy2, sx2 + sw2, sy2 + 54 * scale], fill=(30, 41, 59))
    draw.text((sx2 + 16 * scale, sy2 + 10 * scale), "Checkout & Payment Settlement", fill=(255, 255, 255), font=f_app)
    draw.text((sx2 + 16 * scale, sy2 + 28 * scale), "Bill #INV-2026-0485 • Offline Master", fill=SIDEBAR_TEXT, font=f_reg)

    # Thermal Receipt Card Style
    rcpt_x = sx2 + 14 * scale
    rcpt_y = sy2 + 66 * scale
    rcpt_w = sw2 - 28 * scale
    rcpt_h = sh2 - 80 * scale
    draw.rounded_rectangle([rcpt_x, rcpt_y, rcpt_x + rcpt_w, rcpt_y + rcpt_h], radius=10 * scale, fill=CARD_BG, outline=BORDER_COLOR, width=scale)
    
    # Store Branding on receipt
    f_store = get_font(FONT_BOLD, 13, scale)
    f_store_sub = get_font(FONT_REGULAR, 8, scale)
    draw.text((rcpt_x + 60 * scale, rcpt_y + 14 * scale), "WEBOTAPP SUPERMARKET", fill=TEXT_MAIN, font=f_store)
    draw.text((rcpt_x + 52 * scale, rcpt_y + 32 * scale), "GSTIN: 27AABCS1429B1Z • 100% Tax Compliant", fill=TEXT_MUTED, font=f_store_sub)
    draw.line([rcpt_x + 12 * scale, rcpt_y + 48 * scale, rcpt_x + rcpt_w - 12 * scale, rcpt_y + 48 * scale], fill=(226, 232, 240), width=scale)

    # Line Items Breakdown
    cart_lines = [
        ("Amul Gold Milk 500ml", "1", "₹33.00", "0%"),
        ("Tata Salt Iodized 1kg", "2", "₹56.00", "0%"),
        ("Basmati Rice Feast 1kg", "1", "₹120.00", "5%"),
        ("Fortune Refined Oil 1L", "1", "₹145.00", "5%"),
        ("Baker's Choice Bread", "1", "₹22.50", "0% [CLEARANCE]"),
    ]
    
    cy = rcpt_y + 56 * scale
    f_mono = get_font(FONT_MONO, 10, scale)
    f_c_item = get_font(FONT_SEMIBOLD, 9, scale)
    f_c_sub = get_font(FONT_REGULAR, 8, scale)
    for c_title, c_q, c_tot, c_tax in cart_lines:
        draw.text((rcpt_x + 14 * scale, cy), c_title, fill=TEXT_MAIN, font=f_c_item)
        draw.text((rcpt_x + rcpt_w - 74 * scale, cy), c_tot, fill=TEXT_MAIN, font=f_mono)
        cy += 14 * scale
        draw.text((rcpt_x + 14 * scale, cy), f"Qty: {c_q}  •  Tax: {c_tax}", fill=TEXT_MUTED, font=f_c_sub)
        cy += 18 * scale

    draw.line([rcpt_x + 12 * scale, cy + 4 * scale, rcpt_x + rcpt_w - 12 * scale, cy + 4 * scale], fill=(226, 232, 240), width=scale)
    cy += 12 * scale

    # Zero-Drift Financials Table
    f_fin_l = get_font(FONT_REGULAR, 9, scale)
    f_fin_v = get_font(FONT_MONO, 9, scale)
    f_grand_l = get_font(FONT_BOLD, 12, scale)
    f_grand_v = get_font(FONT_BOLD, 15, scale)
    
    financials = [
        ("Subtotal (Pre-Tax)", "₹363.24"),
        ("GST Slabs Total (5% Slab)", "₹13.26"),
        ("Clearance Markdown Discount", "-₹22.50"),
        ("Rounding Delta Adjustment", "+₹0.00"),
    ]
    for flbl, fval in financials:
        draw.text((rcpt_x + 14 * scale, cy), flbl, fill=TEXT_MUTED, font=f_fin_l)
        col = SUCCESS_EMERALD if "-" in fval else TEXT_MAIN
        draw.text((rcpt_x + rcpt_w - 80 * scale, cy), fval, fill=col, font=f_fin_v)
        cy += 18 * scale

    # Total Box
    draw.rounded_rectangle([rcpt_x + 12 * scale, cy + 6 * scale, rcpt_x + rcpt_w - 12 * scale, cy + 46 * scale], radius=6 * scale, fill=(248, 250, 252))
    draw.text((rcpt_x + 22 * scale, cy + 18 * scale), "NET AMOUNT PAYABLE", fill=TEXT_MAIN, font=f_grand_l)
    draw.text((rcpt_x + rcpt_w - 110 * scale, cy + 16 * scale), "₹376.50", fill=PRIMARY_DARK, font=f_grand_v)
    cy += 54 * scale

    # Payment Tender Buttons (Cash, UPI QR, Card)
    f_pay = get_font(FONT_BOLD, 9, scale)
    p_modes = [("💵 Cash (F4)", (241, 245, 249), TEXT_MAIN), ("📱 UPI QR (F5)", SUCCESS_BG, SUCCESS_EMERALD), ("💳 Card (F6)", (241, 245, 249), TEXT_MAIN)]
    t_x = rcpt_x + 12 * scale
    for p_name, p_bg, p_fg in p_modes:
        pw = (rcpt_w - 36 * scale) // 3
        draw.rounded_rectangle([t_x, cy, t_x + pw, cy + 34 * scale], radius=6 * scale, fill=p_bg)
        draw.text((t_x + 6 * scale, cy + 10 * scale), p_name, fill=p_fg, font=f_pay)
        t_x += pw + 6 * scale
    cy += 44 * scale

    # Share and Thermal Print Actions
    draw.rounded_rectangle([rcpt_x + 12 * scale, cy, rcpt_x + rcpt_w - 12 * scale, cy + 42 * scale], radius=6 * scale, fill=PRIMARY_INDIGO)
    draw.text((rcpt_x + 40 * scale, cy + 12 * scale), "🖨️ Print 58mm Thermal Receipt", fill=(255, 255, 255), font=f_chk_txt)

    im_final = im.resize((w, h), Image.Resampling.LANCZOS)
    im_final.save(os.path.join(OUTPUT_DIR, "mobile-cashier-suite.png"), "PNG", optimize=True)
    print("Generated mobile-cashier-suite.png")

if __name__ == "__main__":
    generate_dashboard()
    generate_catalog()
    generate_low_stock()
    generate_expiry_tracker()
    generate_mobile_suite()
    print("All screenshots generated successfully!")
