import type { Metadata } from "next";
import "./globals.css";
import Navigation from "@/components/layout/Navigation";

export const metadata: Metadata = {
  title: "Light Bus - E-Learning Platform",
  description: "Master any subject with scientifically-proven spaced repetition learning. Light Bus makes learning efficient, engaging, and effective.",
  keywords: "e-learning, spaced repetition, flashcards, education, study, learning platform",
  authors: [{ name: "Light Bus Team" }],
  viewport: "width=device-width, initial-scale=1",
  robots: "index, follow",
  openGraph: {
    title: "Light Bus - E-Learning Platform",
    description: "Master any subject with scientifically-proven spaced repetition learning.",
    type: "website",
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title: "Light Bus - E-Learning Platform",
    description: "Master any subject with scientifically-proven spaced repetition learning.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="min-h-full">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
      </head>
      <body className="min-h-screen font-sans bg-neutral-white text-neutral-charcoal antialiased">
        <div className="min-h-screen flex flex-col">
          <Navigation />
          <main className="flex-1 min-h-0">
            {children}
          </main>
          <footer className="bg-neutral-charcoal text-white py-8 mt-auto shrink-0 w-full">
            <div className="container mx-auto px-4 max-w-7xl">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
                <div>
                  <h3 className="text-xl font-bold mb-4 text-achievement-500">🚌 Light Bus</h3>
                  <p className="text-neutral-gray">
                    Making learning efficient and effective through scientifically-proven spaced repetition.
                  </p>
                </div>
                <div>
                  <h4 className="font-semibold mb-3">Platform</h4>
                  <ul className="space-y-2 text-neutral-gray">
                    <li><a href="/features" className="hover:text-white transition-colors">Features</a></li>
                    <li><a href="/pricing" className="hover:text-white transition-colors">Pricing</a></li>
                    <li><a href="/about" className="hover:text-white transition-colors">About</a></li>
                  </ul>
                </div>
                <div>
                  <h4 className="font-semibold mb-3">Support</h4>
                  <ul className="space-y-2 text-neutral-gray">
                    <li><a href="/help" className="hover:text-white transition-colors">Help Center</a></li>
                    <li><a href="/contact" className="hover:text-white transition-colors">Contact</a></li>
                    <li><a href="/privacy" className="hover:text-white transition-colors">Privacy</a></li>
                  </ul>
                </div>
              </div>
              <div className="border-t border-neutral-gray border-opacity-20 pt-8 mt-8 text-center text-neutral-gray">
                <p>&copy; 2024 Light Bus. All rights reserved. Built with ❤️ for learners everywhere.</p>
              </div>
            </div>
          </footer>
        </div>
      </body>
    </html>
  );
}
