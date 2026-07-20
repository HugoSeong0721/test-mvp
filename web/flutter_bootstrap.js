{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      const loader = document.getElementById('app-loader');
      if (loader) {
        loader.remove();
      }
    } catch (error) {
      const loader = document.getElementById('app-loader');
      if (loader) {
        loader.innerHTML = '<strong>Could not open the app.</strong><div style="margin-top:12px; line-height:1.5;">Open the <a href="mvp-ui-flow-board.html" style="color:#145245; font-weight:700;">visual UI flow board</a> while this is being fixed.</div>';
      }
      throw error;
    }
  }
});
