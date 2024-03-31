import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;
  InAppWebViewSettings settings = InAppWebViewSettings(
    isInspectable: kDebugMode,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    iframeAllow: "camera; microphone",
    iframeAllowFullscreen: true,
    userAgent:
        "Mozilla/5.0 (Linux; Android 9; LG-H870 Build/PKQ1.190522.001) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/83.0.4103.106 Mobile Safari/537.36",
    javaScriptEnabled: true,
    allowsBackForwardNavigationGestures: true,
  );

  PullToRefreshController? pullToRefreshController;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();

    pullToRefreshController = kIsWeb
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(
              color: Colors.blue,
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                webViewController?.loadUrl(
                    urlRequest:
                        URLRequest(url: await webViewController?.getUrl()));
              }
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    bool isKeyboardShown = 0 < MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        // detect Android back button click
        final controller = webViewController;
        if (controller != null) {
          if (await controller.canGoBack()) {
            controller.goBack();
            return;
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
            child: Column(children: <Widget>[
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  key: webViewKey,
                  initialUrlRequest:
                      URLRequest(url: WebUri("https://scrapbox.io/")),
                  initialSettings: settings,
                  initialUserScripts: UnmodifiableListView<UserScript>([
                    UserScript(source: """
globalThis.window.addEventListener('load', (_event) => {
    const style = document.createElement('style');
    style.innerHTML = ".app {padding-top:0px;} .quick-launch .flex-box {display: none;} .btn.project-home{ display: none; } .navbar.navbar-default { display: none;} .new-button { display: none;}";
    document.head.appendChild(style);
});

function flutterCopy() {
    const textInput = document.getElementById("text-input");
    window.flutter_inappwebview.callHandler('handlerCopy', textInput.value);
}

function flutterCut() {
    const textInput = document.getElementById("text-input");
    window.flutter_inappwebview.callHandler('handlerCopy', textInput.value);
    const options = {
      bubbles: true,
      cancelable: true,
      keyCode: 8,
    };
    document.getElementById("text-input").dispatchEvent(new KeyboardEvent( "keydown", options));
    document.getElementById("text-input").dispatchEvent(new KeyboardEvent( "keyup", options));
}

function indent() {
    const options = {
      bubbles: true,
      cancelable: true,
      keyCode: 39,  // ArrowRight
      ctrlKey: true,
    };
    document.getElementById("text-input").dispatchEvent(new KeyboardEvent( "keydown", options));
    document.getElementById("text-input").dispatchEvent(new KeyboardEvent( "keyup", options)); 
}

function outdent() {
    const options = {
      bubbles: true,
      cancelable: true,
      keyCode: 37,  // ArrowLeft
      ctrlKey: true,
    };
    document.getElementById("text-input").dispatchEvent(new KeyboardEvent( "keydown", options));
    document.getElementById("text-input").dispatchEvent(new KeyboardEvent( "keyup", options)); 
}

function upLines() {
    const options = {
      bubbles: true,
      cancelable: true,
      keyCode: 38,
      ctrlKey: true,
    };
    document.getElementById("text-input").dispatchEvent(new KeyboardEvent( "keydown", options));
    document.getElementById("text-input").dispatchEvent(new KeyboardEvent( "keyup", options)); 
}

function downLines() {
    const options = {
      bubbles: true,
      cancelable: true,
      keyCode: 40,
      ctrlKey: true,
    };
    document.getElementById("text-input").dispatchEvent(new KeyboardEvent( "keydown", options));
    document.getElementById("text-input").dispatchEvent(new KeyboardEvent( "keyup", options)); 
}

function openProjects() {
  document.querySelector('.navbar-brand').dispatchEvent(new Event('click', {bubbles: true, cancelable: true}));
}

""", injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
                  ]),
                  pullToRefreshController: pullToRefreshController,
                  onWebViewCreated: (controller) {
                    webViewController = controller;
                    controller.addJavaScriptHandler(
                        handlerName: 'handlerCopy',
                        callback: (args) async {
                          var text = args[0];
                          await Clipboard.setData(ClipboardData(text: text));
                        });
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      this.url = url.toString();
                      urlController.text = this.url;
                    });
                  },
                  onPermissionRequest: (controller, request) async {
                    return PermissionResponse(
                        resources: request.resources,
                        action: PermissionResponseAction.GRANT);
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                    var uri = navigationAction.request.url!;

                    if (![
                      "http",
                      "https",
                      "file",
                      "chrome",
                      "data",
                      "javascript",
                      "about"
                    ].contains(uri.scheme)) {
                      if (await canLaunchUrl(uri)) {
                        // Launch the App
                        await launchUrl(
                          uri,
                        );
                        // and cancel the request
                        return NavigationActionPolicy.CANCEL;
                      }
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  onLoadStop: (controller, url) async {
                    pullToRefreshController?.endRefreshing();
                    setState(() {
                      this.url = url.toString();
                      urlController.text = this.url;
                    });
                  },
                  onReceivedError: (controller, request, error) {
                    pullToRefreshController?.endRefreshing();
                  },
                  onProgressChanged: (controller, progress) {
                    if (progress == 100) {
                      pullToRefreshController?.endRefreshing();
                    }
                    setState(() {
                      this.progress = progress / 100;
                      urlController.text = url;
                    });
                  },
                  onUpdateVisitedHistory: (controller, url, androidIsReload) {
                    setState(() {
                      this.url = url.toString();
                      urlController.text = this.url;
                    });
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    if (kDebugMode) {
                      print(consoleMessage);
                    }
                  },
                ),
                progress < 1.0
                    ? LinearProgressIndicator(value: progress)
                    : Container(),
              ],
            ),
          ),
          if (isKeyboardShown)
            SizedBox(
                height: 40,
                child: Container(
                  color: Colors.black12,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: IconButton(
                          onPressed: () {
                            webViewController?.evaluateJavascript(
                                source: 'outdent();');
                          },
                          icon: const Icon(
                            Icons.chevron_left,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: IconButton(
                          onPressed: () {
                            webViewController?.evaluateJavascript(
                                source: 'indent();');
                          },
                          icon: const Icon(
                            Icons.chevron_right,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: IconButton(
                          onPressed: () {
                            webViewController?.evaluateJavascript(
                                source: 'upLines();');
                          },
                          icon: const Icon(
                            Icons.expand_less,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: IconButton(
                          onPressed: () {
                            webViewController?.evaluateJavascript(
                                source: 'downLines();');
                          },
                          icon: const Icon(
                            Icons.expand_more,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: IconButton(
                          onPressed: () async {
                            webViewController?.evaluateJavascript(
                                source: 'flutterCut();');
                          },
                          icon: const Icon(
                            Icons.content_cut,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: IconButton(
                          onPressed: () async {
                            webViewController?.evaluateJavascript(
                                source: 'flutterCopy();');
                          },
                          icon: const Icon(
                            Icons.replay,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          if (!isKeyboardShown)
            SizedBox(
                height: 40,
                child: Container(
                    color: Colors.grey,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: IconButton(
                            onPressed: () {
                              webViewController?.evaluateJavascript(
                                  source:
                                      "document.querySelector('.navbar-brand').dispatchEvent(new Event('click', {bubbles: true, cancelable: true}));");
                            },
                            icon: const Icon(Icons.apps),
                          ),
                        ),
                        Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: IconButton(
                              onPressed: () async {
                                var currentWebUri =
                                    await webViewController?.getUrl() as Uri;
                                if (kDebugMode) {
                                  print(currentWebUri.path);
                                }
                                var projectName =
                                    currentWebUri.path.split("/")[1];
                                if (kDebugMode) {
                                  print(projectName);
                                }
                                Uri uri = Uri(
                                  scheme: currentWebUri.scheme,
                                  host: currentWebUri.host,
                                  path: "/$projectName/new",
                                  // queryParameters: currentUrl.queryParameters,
                                );
                                if (kDebugMode) {
                                  print(uri);
                                }
                                // await launchUrl(uri);
                                await webViewController?.loadUrl(
                                    urlRequest:
                                        URLRequest(url: WebUri.uri(uri)));
                              },
                              icon: const Icon(Icons.add),
                            )),
                        Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: IconButton(
                            onPressed: () async {
                              var currentWebUri =
                                  await webViewController?.getUrl() as Uri;
                              var projectName =
                                  currentWebUri.path.split("/")[1];
                              if (kDebugMode) {
                                print(projectName);
                              }
                              Uri uri = Uri(
                                scheme: currentWebUri.scheme,
                                host: currentWebUri.host,
                                path: "/$projectName",
                              );
                              await webViewController?.loadUrl(
                                  urlRequest: URLRequest(url: WebUri.uri(uri)));
                            },
                            icon: const Icon(Icons.home),
                          ),
                        ),
                      ],
                    ))),
        ])),
      ),
    );
  }
}
