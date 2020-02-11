import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat/stream_chat.dart';
import 'package:stream_chat_example/channel.bloc.dart';
import 'package:stream_chat_example/components/channel_widget.dart';
import 'package:stream_chat_example/main.dart';

import '../chat.bloc.dart';
import 'channel_header.dart';
import 'channel_list_app_bar.dart';
import 'channel_list_view.dart';
import 'channel_preview.dart';

class ChannelListPage extends StatefulWidget {
  final Map<String, dynamic> filter;
  final Map<String, dynamic> options;
  final List<SortOption> sort;
  final PaginationParams pagination;

  ChannelListPage({
    this.filter,
    this.sort,
    this.pagination,
    this.options,
  });

  @override
  ChannelListPageState createState() => ChannelListPageState();
}

class ChannelListPageState extends State<ChannelListPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  String _selectedChannelId;
  bool showSplit;

  @override
  Widget build(BuildContext context) {
    showSplit = MediaQuery.of(context).size.width > 1000;
    return Consumer<ChatBloc>(
      builder: (context, ChatBloc chatBloc, _) => Flex(
        direction: Axis.horizontal,
        children: <Widget>[
          Flexible(
            flex: 1,
            child: Scaffold(
              key: _scaffoldKey,
              appBar: ChannelListAppBar(),
              body: StreamBuilder<List<ChannelState>>(
                stream: chatBloc.channelsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(snapshot.error.toString()),
                    );
                  } else if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(),
                    );
                  } else {
                    return RefreshIndicator(
                      onRefresh: () async {
                        chatBloc.clearChannels();
                        return chatBloc.queryChannels(
                          widget.filter,
                          widget.sort,
                          widget.pagination,
                          widget.options,
                        );
                      },
                      child: ChannelListView(
                        scrollController: _scrollController,
                        channelsStates: snapshot.data,
                        channelPreviewBuilder: (context, channelState) {
                          return ChannelPreview(
                            onTap: () {
                              _navigateToChannel(
                                context,
                                chatBloc.channelBlocs[channelState.channel.id],
                              );
                            },
                          );
                        },
                      ),
                    );
                  }
                },
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {},
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.send,
                ),
              ),
            ),
          ),
          showSplit
              ? Flexible(
                  flex: 2,
                  child: _selectedChannelId == null
                      ? Scaffold(
                          body: Center(
                            child: Text(
                              'Pick a channel to show the messages 💬',
                              style: Theme.of(context).textTheme.headline3,
                            ),
                          ),
                        )
                      : ChangeNotifierProvider<ChannelBloc>.value(
                          value: chatBloc.channelBlocs[_selectedChannelId],
                          child: ChannelWidget(
                            channelHeader: ChannelHeader(
                              showBackButton: false,
                            ),
                          ),
                        ),
                )
              : Container(),
        ],
      ),
    );
  }

  void _navigateToChannel(BuildContext context, ChannelBloc channelBloc) {
    if (this.showSplit) {
      setState(() {
        _selectedChannelId = channelBloc.channelState.channel.id;
      });
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            return ChangeNotifierProvider<ChannelBloc>.value(
              value: channelBloc,
              child: ChannelWidget(
                channelHeader: ChannelHeader(),
              ),
            );
          },
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    final chatBloc = Provider.of<ChatBloc>(context, listen: false);
    chatBloc.queryChannels(
      widget.filter,
      widget.sort,
      widget.pagination,
      widget.options,
    );

    _scrollController.addListener(() {
      _listenChannelPagination(chatBloc);
    });

    chatBloc.client.wsConnectionStatus.addListener(() {
      _scaffoldKey.currentState.removeCurrentSnackBar();

      if (chatBloc.client.wsConnectionStatus.value ==
          ConnectionStatus.disconnected) {
        _scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text('Disconnected'),
          duration: Duration(minutes: 1),
        ));
      } else if (chatBloc.client.wsConnectionStatus.value ==
          ConnectionStatus.connecting) {
        _scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text('Reconnecting'),
          duration: Duration(seconds: 30),
        ));
      } else if (chatBloc.client.wsConnectionStatus.value ==
          ConnectionStatus.connected) {
        _scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text('Connected'),
        ));

        setState(() {
          chatBloc.clearChannels();
        });

        chatBloc.queryChannels(
          widget.filter,
          widget.sort,
          widget.pagination,
          widget.options,
        );
      }
    });
  }

  void _listenChannelPagination(ChatBloc chatBloc) {
    if (_scrollController.position.maxScrollExtent ==
        _scrollController.position.pixels) {
      chatBloc.queryChannels(
        widget.filter,
        widget.sort,
        widget.pagination.copyWith(
          offset: chatBloc.channels.length,
        ),
        widget.options,
      );
    }
  }
}