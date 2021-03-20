import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edity',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        textTheme: TextTheme(
          bodyText2: TextStyle(fontSize: 16),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        textTheme: ThemeData.dark().textTheme.copyWith(
              bodyText2: TextStyle(fontSize: 16),
            ),
      ),
      home: MainPage(),
    );
  }
}

//Intents
class NewFileIntent extends Intent {
  const NewFileIntent();
}

class OpenFileIntent extends Intent {
  const OpenFileIntent();
}

class SaveFileIntent extends Intent {
  const SaveFileIntent();
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String text = '';
  bool horizontalMode = true;

  double screenWidth = 0;
  final breakWidth = 800;

  TextEditingController textEditingController = TextEditingController();

  void changeText(String newText) {
    text = newText;
    setState(() => textEditingController.text = text);
  }

  Future<bool> saveFile() async {
    if (text.length > 0)
      try {
        await FileSaver.instance.saveFile(
            'edity-${DateTime.now().toString()}', utf8.encode(text), 'txt',
            mimeType: MimeType.TEXT);
      } catch (e) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error during saving'),
            content: Text("Make sure this website can download files."),
            actions: [
              TextButton(
                child: Text('Close'),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        );
        return false;
      }

    return true;
  }

  Future<bool> openFile() async {
    FilePickerResult result = await FilePicker.platform.pickFiles();

    if (result != null) {
      PlatformFile file = result.files.first;

      try {
        text = utf8.decode(file.bytes);
        setState(() => textEditingController.text = text);
      } catch (e) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error during file processing'),
            content: Text("Make sure you've selected an UTF-8 file."),
            actions: [
              TextButton(
                child: Text('Close'),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        );
        return false;
      }
    }

    return true;
  }

  void newFile() async {
    bool errored = false;

    if (text.length > 0)
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('File saved?'),
          content: Text("If needed, save your file before creating a new one."),
          actions: [
            TextButton(
              child: Text('Ignore'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () async {
                errored = !await saveFile();
                Navigator.pop(context);
              },
            )
          ],
        ),
      );

    if (!errored) {
      text = '';
      setState(() => textEditingController.text = text);
    }
  }

  Widget mainMenu() {
    Widget menuListTile(String text, String shortcut, IconData icon, function) {
      Widget listTile = ListTile(
        leading: Icon(icon),
        title: Text(text + (screenWidth >= breakWidth ? ' ($shortcut)' : '')),
        onTap: function,
      );

      return SizedBox(
        width: screenWidth >= breakWidth
            ? 200
            : MediaQuery.of(context).size.width / 3,
        child: listTile,
      );
    }

    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        menuListTile('New', 'Alt + N', Icons.add, newFile),
        menuListTile('Save', 'Alt + S', Icons.save, saveFile),
        menuListTile(
          'Load',
          'Alt + O',
          Icons.file_upload,
          openFile,
        ),
        if (screenWidth >= breakWidth)
          SizedBox(
            width: 200,
            child: SwitchListTile.adaptive(
              value: horizontalMode,
              onChanged: (bool value) => setState(() => horizontalMode = value),
              title: Text('Horizontal disposition'),
            ),
          ),
      ],
    );
  }

  dynamic editorAndVisualizer() {
    void addLink() {
      String title = '';
      String link = '';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Insert a link'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: TextField(
                autofocus: true,
                onChanged: (String value) => setState(() => link = value),
                decoration: InputDecoration(labelText: 'Link'),
              ),
            ),
            TextField(
              onChanged: (String value) => setState(() => title = value),
              decoration: InputDecoration(labelText: 'Title'),
            ),
          ]),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
                child: Text('Insert'),
                onPressed: () {
                  if (link != '') {
                    if (title == '') title = link;
                    changeText(text + "[$title]($link)");
                  }

                  Navigator.pop(context);
                }),
          ],
        ),
      );
    }

    Widget toolboxButton(IconData icon, String tooltip, function) => IconButton(
          splashRadius: 1,
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: function,
        );

    final Widget textField = Flexible(
      flex: 4,
      child: Column(children: [
        TextField(
          autofocus: true,
          controller: textEditingController,
          onChanged: (String value) => setState(() => text = value),
          maxLines: null,
        ),
        SizedBox(
          height: 24,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              toolboxButton(
                  Icons.format_bold, 'Bold', () => changeText(text + '****')),
              toolboxButton(
                  Icons.format_italic, 'Italic', () => changeText(text + '__')),
              toolboxButton(Icons.link, 'Add a link', addLink),
            ],
          ),
        ),
      ]),
    );

    final Widget markdownWidget = Flexible(
        flex: 5,
        child: text.length > 0
            ? Padding(
                padding: EdgeInsets.only(
                    top: horizontalMode ? 0 : 10,
                    left: horizontalMode ? 10 : 0),
                child: MarkdownWidget(
                  data: text,
                  styleConfig: StyleConfig(
                    titleConfig: TitleConfig(divider: SizedBox.shrink()),
                    pConfig: PConfig(
                        selectable: true,
                        onLinkTap: (String link) async {
                          if (await canLaunch(link)) launch(link);
                        }),
                    markdownTheme:
                        Theme.of(context).brightness == Brightness.light
                            ? MarkdownTheme.lightTheme
                            : MarkdownTheme.darkTheme,
                  ),
                ),
              )
            : SizedBox.shrink());

    if (screenWidth < breakWidth) setState(() => horizontalMode = false);

    if (horizontalMode)
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          textField,
          markdownWidget,
        ],
      );
    else
      return Column(
        children: [
          textField,
          markdownWidget,
        ],
      );
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edity'),
      ),
      body: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyN):
              const NewFileIntent(),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyO):
              const OpenFileIntent(),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyS):
              const SaveFileIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            NewFileIntent: CallbackAction<NewFileIntent>(
              onInvoke: (NewFileIntent intent) => newFile(),
            ),
            OpenFileIntent: CallbackAction<OpenFileIntent>(
              onInvoke: (OpenFileIntent intent) => openFile(),
            ),
            SaveFileIntent: CallbackAction<SaveFileIntent>(
              onInvoke: (SaveFileIntent intent) => saveFile(),
            ),
          },
          child: Focus(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: SizedBox(
                        height: 48,
                        child: mainMenu(),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(),
                    ),
                    Expanded(
                      child: editorAndVisualizer(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
