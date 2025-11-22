import SwiftUI
import WebKit

struct StudioHTMLView: View {
    private let studioHTML: String = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Studio</title>
        <style>
            :root {
                color-scheme: dark;
                --bg: #050505;
                --panel: rgba(255,255,255,0.05);
                --border: rgba(255,255,255,0.12);
                --text: #f4f4f4;
                --accent: #5DE0E6;
            }
            * {
                box-sizing: border-box;
                font-family: "SF Pro Display", "Helvetica Neue", Helvetica, Arial, sans-serif;
            }
            body {
                margin: 0;
                padding: 28px 18px 60px;
                background: var(--bg);
                color: var(--text);
            }
            header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 24px;
            }
            header h1 {
                font-size: 34px;
                margin: 0;
                letter-spacing: 0.5px;
            }
            header span {
                font-size: 13px;
                opacity: 0.7;
            }
            .grid {
                display: grid;
                grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
                gap: 16px;
            }
            .card {
                position: relative;
                border-radius: 24px;
                padding: 16px;
                min-height: 200px;
                background: var(--panel);
                border: 1px solid var(--border);
                overflow: hidden;
                backdrop-filter: blur(14px);
            }
            .card img {
                position: absolute;
                inset: 0;
                width: 100%;
                height: 100%;
                object-fit: cover;
                border-radius: 24px;
                filter: brightness(0.82);
            }
            .card .content {
                position: relative;
                z-index: 2;
            }
            .tag {
                display: inline-flex;
                align-items: center;
                gap: 6px;
                font-size: 12px;
                padding: 6px 12px;
                border-radius: 40px;
                background: rgba(0,0,0,0.35);
                border: 1px solid rgba(255,255,255,0.1);
                backdrop-filter: blur(6px);
            }
            .tag::before {
                content: "";
                width: 6px;
                height: 6px;
                border-radius: 50%;
                background: var(--accent);
            }
            .card h2 {
                margin: 18px 0 4px;
                font-size: 18px;
            }
            .card p {
                margin: 0;
                opacity: 0.75;
                font-size: 13px;
                line-height: 1.4;
            }
            .cta {
                margin-top: 16px;
                display: inline-flex;
                align-items: center;
                gap: 6px;
                font-weight: 600;
                color: var(--accent);
                font-size: 14px;
            }
        </style>
    </head>
    <body>
        <header>
            <h1>Studio</h1>
            <span>3:43 · 🌙 Night Mode</span>
        </header>

        <section class="grid">
            <article class="card">
                <img src="https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=700&q=80" alt="Ocean" />
                <div class="content">
                    <span class="tag">Live widget</span>
                    <h2>Circulus Clock</h2>
                    <p>柔和的生物气泡主题小组件，为主屏带来有机呼吸感。</p>
                    <div class="cta">Play</div>
                </div>
            </article>

            <article class="card">
                <img src="https://images.unsplash.com/photo-1454165205744-3b78555e5572?auto=format&fit=crop&w=700&q=80" alt="Stars" />
                <div class="content">
                    <span class="tag">Prototype</span>
                    <h2>Mystic Journey</h2>
                    <p>沉浸式魔法森林互动体验，收集灵感碎片。</p>
                    <div class="cta">Begin Journey</div>
                </div>
            </article>

            <article class="card">
                <img src="https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=700&q=80" alt="Chat" />
                <div class="content">
                    <span class="tag">AI Chat</span>
                    <h2>Chat with Aristotle</h2>
                    <p>提出你的问题，让哲学家陪你思辨。</p>
                    <div class="cta">Ask</div>
                </div>
            </article>

            <article class="card">
                <img src="https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=700&q=80" alt="Forest" />
                <div class="content">
                    <span class="tag">Story</span>
                    <h2>Mystical Journey</h2>
                    <p>沿着月光指引在迷雾森林探索故事线索。</p>
                    <div class="cta">Continue</div>
                </div>
            </article>

            <article class="card">
                <img src="https://images.unsplash.com/photo-1470770903676-69b98201ea1c?auto=format&fit=crop&w=700&q=80" alt="Score" />
                <div class="content">
                    <span class="tag">Game</span>
                    <h2>Score: 0</h2>
                    <p>轻点精灵收集星尘，升级你的世界观。</p>
                    <div class="cta">Play Demo</div>
                </div>
            </article>

            <article class="card">
                <img src="https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=700&q=80" alt="Dream" />
                <div class="content">
                    <span class="tag">Ambient</span>
                    <h2>Dreamscape</h2>
                    <p>在蓝色梦境里，设计下一段奇遇。</p>
                    <div class="cta">Open Studio</div>
                </div>
            </article>
        </section>
    </body>
    </html>
    """

    var body: some View {
        StudioWebView(html: studioHTML)
            .navigationTitle("Studio")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.black)
            .ignoresSafeArea(edges: .bottom)
    }
}

private struct StudioWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url == nil && uiView.isLoading == false {
            uiView.loadHTMLString(html, baseURL: nil)
        }
    }
}
