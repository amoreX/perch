import Navbar from './components/Navbar';
import Hero from './components/Hero';
import Features from './components/Features';
import Download from './components/Download';
import Footer from './components/Footer';

export default function PerchSite() {
  return (
    <div className="bg-white min-h-screen">
      <div className="fixed left-0 top-0 bottom-0 z-50 w-[10px] bg-[#111111] pointer-events-none" />
      <div className="fixed right-0 top-0 bottom-0 z-50 w-[10px] bg-[#111111] pointer-events-none" />
      <Navbar />
      <main>
        <Hero />
        <Features />
        <Download />
      </main>
      <Footer />
    </div>
  );
}
