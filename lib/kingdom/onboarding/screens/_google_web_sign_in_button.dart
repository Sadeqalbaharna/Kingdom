// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:html' as html;
import 'dart:js' as js;

class _GoogleWebSignInButton extends StatefulWidget {
  final Future<void> Function() onSignedIn;
  final bool busy;
  const _GoogleWebSignInButton({required this.onSignedIn, required this.busy});

  @override
  State<_GoogleWebSignInButton> createState() => _GoogleWebSignInButtonState();
  }

class _GoogleWebSignInButtonState extends State<_GoogleWebSignInButton> {
  html.DivElement? _container;
  @override
  void initState() {
    super.initState();
    _renderButton();
  }

  @override
  void dispose() {
    _container?.remove();
    super.dispose();
  }

  void _renderButton() {
    // Remove any previous button
    _container?.remove();
    _container = html.DivElement();
    _container!.id = 'google-signin-btn';
    _container!.style.width = '240px';
    _container!.style.height = '48px';
    // Remove any existing element with this id
    html.document.getElementById('google-signin-btn')?.remove();

      // Register the view factory only once
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        'google-signin-btn',
        (int viewId) => _container!,
      );
  
      // Load Google's platform.js if not already loaded
      if (html.document.getElementById('gapi-script') == null) {
        final script = html.ScriptElement()
          ..id = 'gapi-script'
          ..src = 'https://accounts.google.com/gsi/client'
          ..async = true
          ..defer = true;
        html.document.body?.append(script);
        script.onLoad.listen((event) {
          _renderGoogleButton();
        });
      } else {
        _renderGoogleButton();
      }
    }

  void _renderGoogleButton() {
    // ignore: undefined_prefixed_name
    final google = js.context['google'];
    if (google != null) {
      final accounts = google['accounts'];
      final id = accounts != null ? accounts['id'] : null;
      if (id != null) {
        id.callMethod('initialize', [
          js.JsObject.jsify({
            'client_id': '<YOUR_CLIENT_ID>', // Replace with your Google client ID
            'callback': (response) async {
              if (widget.busy) return;
              await widget.onSignedIn();
            },
          })
        ]);
        id.callMethod('renderButton', [
          _container,
          js.JsObject.jsify({
            'theme': 'outline',
            'size': 'large',
            'text': 'signin_with',
            'shape': 'rectangular',
            'width': 240,
            'height': 48,
          })
        ]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: widget.busy,
      child: SizedBox(
        width: 240,
        height: 48,
                child: HtmlElementView(viewType: 'google-signin-btn'),
              ),
            );
          }
        }
      