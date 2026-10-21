export default function Home() {
  return (
    <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col justify-center gap-6 px-4 py-16 sm:px-8">
      <h1
        className="text-7xl font-extrabold leading-[0.9] tracking-tight sm:text-8xl"
        style={{ fontVariationSettings: '"opsz" 96, "wdth" 78' }}
      >
        Off<span className="text-accent-text">stock</span>
      </h1>
      <p className="text-2xl font-semibold">Funciona Aunque Te Salgas.</p>
      <p className="max-w-prose text-lg text-ink-soft">
        Aquí verás las ventas, el inventario y los reportes de tu negocio. El dashboard se construye en la fase 5.
      </p>
    </main>
  );
}
