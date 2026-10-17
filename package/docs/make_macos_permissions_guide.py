#!/usr/bin/env python3
#
# Generates AudioGridder-macOS-Permissions.pdf, the guide for granting the
# Accessibility and Screen Recording permissions to AudioGridder Server.
#
# Requires reportlab (pip install reportlab).
#
# Usage: make_macos_permissions_guide.py [output.pdf]

import os
import sys

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (KeepTogether, ListFlowable, ListItem, Paragraph, Preformatted, SimpleDocTemplate,
                                Spacer, Table, TableStyle)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

VERSION = open(os.path.join(ROOT, "package", "VERSION.num")).read().strip()
BUNDLE_ID = "com.e47.AudioGridderServer"

INK = colors.HexColor("#1d2330")
MUTED = colors.HexColor("#5b6475")
ACCENT = colors.HexColor("#2f6fdf")
RULE = colors.HexColor("#d9dee8")
NOTE_BG = colors.HexColor("#eef3fc")
WARN_BG = colors.HexColor("#fdf3e3")
WARN_EDGE = colors.HexColor("#d9902f")
CODE_BG = colors.HexColor("#f3f4f7")

base = ParagraphStyle("base", fontName="Helvetica", fontSize=10, leading=13.8, textColor=INK, alignment=TA_LEFT)
title = ParagraphStyle("title", parent=base, fontName="Helvetica-Bold", fontSize=22, leading=27, spaceAfter=4)
subtitle = ParagraphStyle("subtitle", parent=base, fontSize=11, leading=15, textColor=MUTED, spaceAfter=14)
h1 = ParagraphStyle("h1", parent=base, fontName="Helvetica-Bold", fontSize=14, leading=18, spaceBefore=11,
                    spaceAfter=6, textColor=INK)
h2 = ParagraphStyle("h2", parent=base, fontName="Helvetica-Bold", fontSize=11, leading=15, spaceBefore=8,
                    spaceAfter=3, textColor=ACCENT)
body = ParagraphStyle("body", parent=base, spaceAfter=6)
small = ParagraphStyle("small", parent=base, fontSize=8.5, leading=12, textColor=MUTED)
cell = ParagraphStyle("cell", parent=base, fontSize=9.5, leading=13)
cell_head = ParagraphStyle("cell_head", parent=cell, fontName="Helvetica-Bold")
code = ParagraphStyle("code", parent=base, fontName="Courier", fontSize=9, leading=12.5)


def p(text, style=body):
    return Paragraph(text, style)


def ui(text):
    """Formats the name of something on screen (menu, button, pane)."""
    return "<b>%s</b>" % text


def steps(items):
    return ListFlowable([ListItem(p(i), leftIndent=14, value=n + 1) for n, i in enumerate(items)],
                        bulletType="1", bulletFontName="Helvetica-Bold", bulletFontSize=10, leftIndent=14,
                        bulletColor=ACCENT, spaceAfter=4)


def bullets(items):
    return ListFlowable([ListItem(p(i), leftIndent=12) for i in items], bulletType="bullet", start="•",
                        leftIndent=12, bulletFontSize=9, spaceAfter=4)


def box(flowables, bg=NOTE_BG, edge=ACCENT):
    t = Table([[flowables]], colWidths=[None])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg),
        ("LINEBEFORE", (0, 0), (0, -1), 3, edge),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    return KeepTogether([Spacer(1, 4), t, Spacer(1, 8)])


def note(text):
    return box([p(text, ParagraphStyle("n", parent=body, spaceAfter=0))])


def warning(text):
    return box([p(text, ParagraphStyle("w", parent=body, spaceAfter=0))], bg=WARN_BG, edge=WARN_EDGE)


def code_block(text):
    t = Table([[Preformatted(text, code)]], colWidths=[None])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), CODE_BG),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    return KeepTogether([t, Spacer(1, 8)])


def table(rows, widths):
    data = [[p(c, cell_head) for c in rows[0]]] + [[p(c, cell) for c in r] for r in rows[1:]]
    t = Table(data, colWidths=widths, repeatRows=1)
    t.setStyle(TableStyle([
        ("LINEBELOW", (0, 0), (-1, 0), 1, INK),
        ("LINEBELOW", (0, 1), (-1, -1), 0.5, RULE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    return KeepTogether([t, Spacer(1, 8)])


def build_story():
    s = []

    s.append(p("AudioGridder on macOS", title))
    s.append(p("Setting up the Accessibility and Screen Recording permissions for AudioGridder Server "
               "&nbsp;&middot;&nbsp; AudioGridder %s &nbsp;&middot;&nbsp; macOS 11.1 and later" % VERSION, subtitle))

    # --- Overview -----------------------------------------------------------------------------------------------
    s.append(p("What you need and why", h1))
    s.append(p("AudioGridder Server shows the plugins it hosts in your DAW and lets you control them from there. "
               "macOS only allows this after you grant AudioGridder Server two privacy permissions. You grant them "
               "once, on the Mac that runs AudioGridder Server."))
    s.append(table([
        ["Permission", "What AudioGridder uses it for", "What happens without it"],
        ["Accessibility",
         "Sends your mouse clicks, drags and key presses to the plugin windows on the server.",
         "You can see plugin windows in your DAW, but clicking or typing in them does nothing. When the server "
         "starts it shows: <i>AudioGridder needs the Accessibility permission to remote control plugins.</i>"],
        ["Screen Recording<br/><font size=8 color='#5b6475'>(macOS 15 and later: Screen &amp; System Audio "
         "Recording)</font>",
         "Captures the plugin windows on the server and streams them to the AudioGridder plugin in your DAW.",
         "The plugin window in your DAW stays black or empty, or shows the desktop instead of the plugin."],
    ], [32 * mm, 58 * mm, 80 * mm]))
    s.append(bullets([
        "You grant both permissions to %s (it is in your Applications folder). The helper processes it starts, "
        "for scanning and sandboxing plugins, are covered by the same permissions." % ui("AudioGridderServer"),
        "The Mac that only runs your DAW does not need either permission, unless AudioGridder Server runs on it too.",
        "AudioGridder does not record audio and does not save screen recordings. The captured plugin windows are "
        "only streamed to the AudioGridder plugin.",
        "Changing these settings needs an administrator account.",
    ]))
    s.append(note("<b>Same Mac for DAW and server?</b> Set %s to %s (see section 4). AudioGridder then shows the "
                  "real plugin windows next to your DAW and Screen Recording is not used. Accessibility is still "
                  "recommended." % (ui("Screen Capturing Mode"), ui("Disabled (Local Mode)"))))

    # --- Accessibility ----------------------------------------------------------------------------------------------
    s.append(p("1. Allow Accessibility", h1))
    s.append(p("macOS 13 Ventura and later", h2))
    s.append(steps([
        "Choose Apple menu > %s." % ui("System Settings"),
        "Click %s in the sidebar, then click %s on the right." % (ui("Privacy &amp; Security"), ui("Accessibility")),
        "Find %s in the list and turn its switch on. Enter your password if asked." % ui("AudioGridderServer"),
        "If AudioGridderServer is not in the list, click the %s button below the list, open the "
        "%s folder, select %s and click %s. Then turn its switch on." % (
            ui("+"), ui("Applications"), ui("AudioGridderServer"), ui("Open")),
        "Restart AudioGridder Server: click the AudioGridder icon in the menu bar and choose %s." % ui("Restart"),
    ]))
    s.append(p("macOS 11 Big Sur and macOS 12 Monterey", h2))
    s.append(steps([
        "Choose Apple menu > %s, then open %s and click the %s tab." % (
            ui("System Preferences"), ui("Security &amp; Privacy"), ui("Privacy")),
        "Click the lock in the bottom-left corner and enter your password.",
        "Select %s on the left, then tick %s. If it is not in the list, click %s and add it from the "
        "Applications folder." % (ui("Accessibility"), ui("AudioGridderServer"), ui("+")),
        "Click the lock again, then restart AudioGridder Server from its menu bar icon.",
    ]))

    # --- Screen Recording -------------------------------------------------------------------------------------------
    s.append(p("2. Allow Screen Recording", h1))
    s.append(p("The first time AudioGridder Server captures a plugin window, macOS asks whether to allow it. Click "
               "%s and continue with step 2 below. You can also set it up in advance:" % ui("Open System Settings")))
    s.append(p("macOS 13 Ventura and later", h2))
    s.append(steps([
        "Choose Apple menu > %s > %s." % (ui("System Settings"), ui("Privacy &amp; Security")),
        "Click %s. On macOS 15 Sequoia and later this is called %s; use the upper section with that name, not "
        "%s." % (ui("Screen Recording"), ui("Screen &amp; System Audio Recording"), ui("System Audio Recording Only")),
        "Turn on %s, or click %s to add it from the Applications folder. Enter your password if asked." % (
            ui("AudioGridderServer"), ui("+")),
        "When macOS asks to quit and reopen AudioGridder Server, choose %s." % ui("Quit &amp; Reopen"),
    ]))
    s.append(p("macOS 11 Big Sur and macOS 12 Monterey", h2))
    s.append(steps([
        "Open %s > %s > %s, click the lock and enter your password." % (
            ui("System Preferences"), ui("Security &amp; Privacy"), ui("Privacy")),
        "Select %s on the left and tick %s." % (ui("Screen Recording"), ui("AudioGridderServer")),
        "Choose %s when asked." % ui("Quit &amp; Reopen"),
    ]))
    s.append(note("<b>macOS 15 Sequoia and later</b> asks again from time to time whether AudioGridderServer may "
                  "keep capturing the screen. Choose the option that keeps allowing it. If you dismiss the "
                  "message, plugin windows in your DAW stop updating until you allow it again."))

    # --- Local network ----------------------------------------------------------------------------------------------
    s.append(p("3. Allow local network access (macOS 15 and later)", h1))
    s.append(p("Starting with macOS 15 Sequoia, apps need permission to connect to other computers on your "
               "network. Click %s when macOS asks:" % ui("Allow")))
    s.append(bullets([
        "on the server Mac, for %s;" % ui("AudioGridderServer"),
        "on the DAW Mac, for your DAW (for example Logic Pro, Ableton Live or Reaper). The AudioGridder plugin "
        "runs inside your DAW, so the DAW is the app that asks.",
    ]))
    s.append(p("To check or change this later, open %s > %s > %s. Without it, the AudioGridder plugin cannot find "
               "or connect to the server." % (ui("System Settings"), ui("Privacy &amp; Security"),
                                              ui("Local Network"))))

    # --- Capture mode -----------------------------------------------------------------------------------------------
    s.append(KeepTogether([p("4. Choose how plugin windows are shown", h1),
                           p("Click the AudioGridder icon in the menu bar, choose %s and open the %s tab. Pick a "
                             "%s, then save:" % (ui("Settings"), ui("Capture"), ui("Screen Capturing Mode"))),
                           table([
        ["Mode", "Use it when", "Needs Screen Recording"],
        ["FFmpeg", "The server is a different Mac. Best quality at the lowest network bandwidth. Recommended.", "Yes"],
        ["Legacy", "FFmpeg does not work for you. Takes a screenshot every 50 ms.", "Yes"],
        ["Disabled (Local Mode)", "Your DAW and AudioGridder Server run on the same Mac. Plugin windows open next "
         "to the AudioGridder plugin window, and you can open several at once.", "No"],
        ["Disabled", "You never need to see plugin windows.", "No"],
    ], [38 * mm, 100 * mm, 32 * mm])]))
    s.append(p("If clicks land slightly off target in a captured window, adjust %s on the same tab." %
               ui("Mouse Offset Correction")))

    # --- Troubleshooting --------------------------------------------------------------------------------------------
    s.append(p("5. Troubleshooting", h1))
    s.append(table([
        ["Problem", "Fix"],
        ["The switch for AudioGridderServer is on, but clicks or the picture still don't work.",
         "The setting belongs to an older copy of the app. This often happens after an update. Select "
         "AudioGridderServer in the list, click %s to remove it, add it again with %s and restart the server." % (
             ui("−"), ui("+"))],
        ["The warning about Accessibility appears every time the server starts.",
         "Accessibility is not granted for the copy of AudioGridderServer you are running. Grant it as in section "
         "1. Make sure you start the server from the Applications folder."],
        ["The plugin window in the DAW is black or shows the desktop.",
         "Screen Recording is missing or was not allowed again on macOS 15 and later. See section 2."],
        ["The DAW does not find the server.",
         "Check Local Network access for the DAW and the server (section 3), and that both Macs are on the same "
         "network."],
        ["The server Mac runs without a screen attached.",
         "Log in a user on the server Mac and keep the session running. macOS cannot capture plugin windows "
         "from the login screen."],
    ], [58 * mm, 112 * mm]))
    s.append(p("Start over", h2))
    s.append(p("To clear both permissions and grant them again, quit AudioGridder Server, open %s (in "
               "Applications > Utilities) and run:" % ui("Terminal")))
    s.append(code_block("tccutil reset Accessibility %s\ntccutil reset ScreenCapture %s" % (BUNDLE_ID, BUNDLE_ID)))
    s.append(p("Then start AudioGridder Server and follow sections 1 and 2 again."))
    s.append(warning("<b>Developer builds.</b> macOS ties these permissions to the app's code signature. An "
                     "unsigned build you compiled yourself counts as a different app and needs its own "
                     "permissions, again after every rebuild. Signed release builds keep their permissions across "
                     "updates."))

    return s


def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.5)
    canvas.line(doc.leftMargin, 14 * mm, A4[0] - doc.rightMargin, 14 * mm)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(doc.leftMargin, 10 * mm, "AudioGridder %s  -  macOS permissions guide" % VERSION)
    canvas.drawRightString(A4[0] - doc.rightMargin, 10 * mm, "Page %d" % doc.page)
    canvas.restoreState()


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "AudioGridder-macOS-Permissions.pdf")
    doc = SimpleDocTemplate(out, pagesize=A4, leftMargin=20 * mm, rightMargin=20 * mm, topMargin=16 * mm,
                            bottomMargin=20 * mm, title="AudioGridder on macOS: Accessibility and Screen Recording",
                            author="AudioGridder", subject="Setting up macOS privacy permissions for AudioGridder "
                            "Server")
    doc.build(build_story(), onFirstPage=footer, onLaterPages=footer)
    print("written", out)


if __name__ == "__main__":
    main()
