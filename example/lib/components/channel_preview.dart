import 'package:animations/animations.dart';
import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat/stream_chat.dart';

import '../stream_channel.dart';
import '../stream_chat.dart';
import 'channel_header.dart';
import 'channel_image.dart';
import 'channel_name_text.dart';
import 'channel_widget.dart';

class ChannelPreview extends StatelessWidget {
  final VoidCallback onTap;

  const ChannelPreview({
    Key key,
    @required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final streamChannel = StreamChannel.of(context);
    return StreamBuilder<ChannelState>(
        stream: streamChannel.channelClient.state.channelStateStream,
        initialData: streamChannel.channelState,
        builder: (context, snapshot) {
          final channelState = snapshot.data;
          return OpenContainer(
            closedColor: Theme.of(context).scaffoldBackgroundColor,
            closedElevation: 0,
            openBuilder: (context, _) {
              return StreamChannel(
                channelClient: StreamChat.of(context)
                    .client
                    .channelClients[channelState.channel.id],
                child: ChannelWidget(
                  channelHeader: ChannelHeader(),
                ),
              );
            },
            closedBuilder: (context, openAction) {
              return StreamChannel(
                channelClient: StreamChat.of(context)
                    .client
                    .channelClients[channelState.channel.id],
                child: ListTile(
                  onTap: () {
                    if (onTap != null) {
                      onTap();
                    } else {
                      openAction();
                    }
                  },
                  leading: ChannelImage(
                    channel: channelState.channel,
                  ),
                  title: ChannelNameText(
                    channel: channelState.channel,
                  ),
                  subtitle: _buildSubtitle(
                    streamChannel,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      _buildDate(context, channelState.channel.lastMessageAt),
                    ],
                  ),
                ),
              );
            },
          );
        });
  }

  Text _buildDate(BuildContext context, DateTime lastMessageAt) {
    String stringDate;
    final now = DateTime.now();

    if (now.year != lastMessageAt.year ||
        now.month != lastMessageAt.month ||
        now.day != lastMessageAt.day) {
      stringDate =
          '${lastMessageAt.day}/${lastMessageAt.month}/${lastMessageAt.year}';
      stringDate = formatDate(lastMessageAt, [dd, '/', mm, '/', yyyy]);
    } else {
      stringDate = '${lastMessageAt.hour}:${lastMessageAt.minute}';
      stringDate = formatDate(lastMessageAt, [HH, ':', nn]);
    }

    return Text(
      stringDate,
      style: Theme.of(context).textTheme.caption,
    );
  }

  Widget _buildSubtitle(
    StreamChannel streamChannel,
  ) {
    return StreamBuilder<List<User>>(
        stream: streamChannel.channelClient.state.typingEventsStream,
        initialData: [],
        builder: (context, snapshot) {
          final typings = snapshot.data;
          final double opacity =
              streamChannel.channelClient.state.unreadCount > 0 ? 1 : 0.5;
          return typings.isNotEmpty
              ? _buildTypings(typings, context, opacity)
              : _buildLastMessage(context, streamChannel, opacity);
        });
  }

  Widget _buildLastMessage(
      BuildContext context, StreamChannel streamChannel, double opacity) {
    final lastMessage = streamChannel.channelState.messages.isNotEmpty
        ? streamChannel.channelState.messages.last
        : null;
    if (lastMessage == null) {
      return SizedBox.fromSize(
        size: Size.zero,
      );
    }

    final prefix = lastMessage.attachments
        .map((e) {
          if (e.type == 'image') {
            return '📷';
          } else if (e.type == 'video') {
            return '🎬';
          }
          return null;
        })
        .where((e) => e != null)
        .join(' ');

    return Text(
      '$prefix ${lastMessage.text ?? ''}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.caption.copyWith(
            color: Colors.black.withOpacity(opacity),
          ),
    );
  }

  Text _buildTypings(List<User> typings, BuildContext context, double opacity) {
    return Text(
      '${typings.map((u) => u.extraData.containsKey('name') ? u.extraData['name'] : u.id).join(',')} ${typings.length == 1 ? 'is' : 'are'} typing...',
      maxLines: 1,
      style: Theme.of(context).textTheme.caption.copyWith(
            color: Colors.black.withOpacity(opacity),
          ),
    );
  }
}
