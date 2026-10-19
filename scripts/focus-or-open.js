// vibe-scrolling (macOS): focus an already open Reels tab, or open a new one.
//
// Usage: osascript -l JavaScript focus-or-open.js <browser> <url> [marker] [terminalBundleId]
//   browser  "default", a short name (safari, chrome, ...) or any app name
//   marker   if given together with terminalBundleId, records "<terminal>\n<browser>"
//            so the Stop hook knows where to send the user back to
//
// With VIBE_SCROLLING_DRY_RUN=1 it only reports what it would do.

ObjC.import('AppKit');

const SAFARI = 'com.apple.Safari';
const KNOWN = {
  safari: SAFARI,
  chrome: 'com.google.Chrome',
  brave: 'com.brave.Browser',
  edge: 'com.microsoft.edgemac',
  arc: 'company.thebrowser.Browser',
  vivaldi: 'com.vivaldi.Vivaldi',
  chromium: 'org.chromium.Chromium',
  firefox: 'org.mozilla.firefox',
};
const CHROMIUM = [KNOWN.chrome, KNOWN.brave, KNOWN.edge, KNOWN.arc, KNOWN.vivaldi, KNOWN.chromium];

const quote = (s) => "'" + String(s).replace(/'/g, "'\\''") + "'";

function bundleIdFor(browser, url) {
  const key = browser.toLowerCase();
  const ws = $.NSWorkspace.sharedWorkspace;
  if (key === 'default') {
    const appUrl = ws.URLForApplicationToOpenURL($.NSURL.URLWithString(url));
    if (appUrl.isNil()) return '';
    const bundle = $.NSBundle.bundleWithURL(appUrl);
    return bundle.isNil() ? '' : ObjC.unwrap(bundle.bundleIdentifier) || '';
  }
  if (KNOWN[key]) return KNOWN[key];
  const path = ws.fullPathForApplication(browser);
  if (path.isNil()) return '';
  const bundle = $.NSBundle.bundleWithPath(path);
  return bundle.isNil() ? '' : ObjC.unwrap(bundle.bundleIdentifier) || '';
}

const isRunning = (id) => $.NSRunningApplication.runningApplicationsWithBundleIdentifier(id).count > 0;
const isScriptable = (id) => id === SAFARI || CHROMIUM.includes(id);

// "https://www.instagram.com/reels/" -> "instagram.com/reels": the URL changes while you scroll.
const needleFor = (url) => url.replace(/^[a-z]+:\/\//i, '').replace(/^www\./i, '').replace(/\/+$/, '');

function focusExisting(id, needle) {
  try {
    const app = Application(id);
    for (const win of app.windows()) {
      const urls = win.tabs.url();
      const i = urls.findIndex((u) => (u || '').includes(needle));
      if (i < 0) continue;
      if (id === SAFARI) {
        win.currentTab = win.tabs[i];
      } else {
        try {
          win.activeTabIndex = i + 1;
        } catch (e) {
          win.tabs[i].select(); // Arc
        }
      }
      win.index = 1;
      app.activate();
      return true;
    }
  } catch (e) {
    // Not scriptable, or the user declined the Automation permission: just open a tab.
  }
  return false;
}

function openUrl(id, browser, url) {
  const sys = Application.currentApplication();
  sys.includeStandardAdditions = true;
  let cmd = `open ${quote(url)}`;
  if (id) cmd = `open -b ${quote(id)} ${quote(url)}`;
  else if (browser.toLowerCase() !== 'default') cmd = `open -a ${quote(browser)} ${quote(url)} || open ${quote(url)}`;
  try {
    sys.doShellScript(cmd);
  } catch (e) {
    try {
      sys.doShellScript(`open ${quote(url)}`);
    } catch (_) {}
  }
}

function run(argv) {
  const [browser = 'default', url = 'https://www.instagram.com/reels/', marker = '', terminal = ''] = argv;
  const dryRun = ObjC.unwrap($.NSProcessInfo.processInfo.environment.objectForKey('VIBE_SCROLLING_DRY_RUN')) === '1';
  const id = bundleIdFor(browser, url);
  const needle = needleFor(url);

  if (dryRun) {
    const action = id && isScriptable(id) && isRunning(id)
      ? `look for a tab matching "${needle}" in ${id}, else open one`
      : `open ${url} in ${id || browser}`;
    return `browser ${browser} -> ${id || '<unresolved>'}; would ${action}` +
      (marker && terminal && id ? `; would write marker ${marker}` : '');
  }

  if (!(id && isScriptable(id) && isRunning(id) && focusExisting(id, needle))) {
    openUrl(id, browser, url);
  }

  if (marker && terminal && id) {
    $(`${terminal}\n${id}\n`).writeToFileAtomicallyEncodingError(marker, true, $.NSUTF8StringEncoding, null);
  }
}
