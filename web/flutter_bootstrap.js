{{flutter_js}}
{{flutter_build_config}}

async function startApp() {
  if ('serviceWorker' in navigator) {
    try {
      const serviceWorkerUrl = new URL('service-worker.js', document.baseURI);
      await navigator.serviceWorker.register(serviceWorkerUrl);
      await navigator.serviceWorker.ready;
    } catch (error) {
      console.error('تعذر تفعيل وضع العمل دون اتصال:', error);
    }
  }

  await _flutter.loader.load();
}

startApp();
