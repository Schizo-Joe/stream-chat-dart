import 'package:json_annotation/json_annotation.dart';

import 'channel_config.dart';
import 'member.dart';
import 'serialization.dart';
import 'user.dart';

part 'channel.g.dart';

/// The class that contains the information about a channel
@JsonSerializable()
class Channel {
  /// The id of this channel
  final String id;

  /// The type of this channel
  final String type;

  /// The cid of this channel
  @JsonKey(includeIfNull: false, toJson: Serialization.readOnly)
  final String cid;

  /// The channel configuration data
  @JsonKey(includeIfNull: false, toJson: Serialization.readOnly)
  final ChannelConfig config;

  /// The user that created this channel
  @JsonKey(includeIfNull: false, toJson: Serialization.readOnly)
  final User createdBy;

  /// True if this channel is frozen
  @JsonKey(includeIfNull: false)
  final bool frozen;

  /// The date of the last message
  @JsonKey(includeIfNull: false, toJson: Serialization.readOnly)
  final DateTime lastMessageAt;

  /// The date of channel creation
  @JsonKey(includeIfNull: false, toJson: Serialization.readOnly)
  final DateTime createdAt;

  /// The date of the last channel update
  @JsonKey(includeIfNull: false, toJson: Serialization.readOnly)
  final DateTime updatedAt;

  /// The date of channel deletion
  @JsonKey(includeIfNull: false, toJson: Serialization.readOnly)
  final DateTime deletedAt;

  /// The count of this channel members
  @JsonKey(includeIfNull: false, toJson: Serialization.readOnly)
  final int memberCount;

  /// The list of this channel members
  @JsonKey(includeIfNull: false)
  final List<Member> members;

  /// Map of custom channel extraData
  @JsonKey(includeIfNull: false)
  final Map<String, dynamic> extraData;

  /// Known top level fields.
  /// Useful for [Serialization] methods.
  static const topLevelFields = [
    'id',
    'type',
    'cid',
    'config',
    'created_by',
    'frozen',
    'last_message_at',
    'created_at',
    'updated_at',
    'deleted_at',
    'member_count',
    'members',
  ];

  /// Constructor used for json serialization
  Channel({
    this.id,
    this.type,
    this.cid,
    this.config,
    this.createdBy,
    this.frozen,
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.memberCount,
    this.members,
    this.extraData,
  });

  /// Create a new instance from a json
  factory Channel.fromJson(Map<String, dynamic> json) {
    return _$ChannelFromJson(
        Serialization.moveKeysToRoot(json, topLevelFields));
  }

  /// Serialize to json
  Map<String, dynamic> toJson() {
    return Serialization.moveKeysToMapInPlace(
      _$ChannelToJson(this),
      topLevelFields,
    );
  }
}
