// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatSessionRecordAdapter extends TypeAdapter<ChatSessionRecord> {
  @override
  final int typeId = 2;

  @override
  ChatSessionRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatSessionRecord(
      id: fields[0] as String,
      title: fields[1] as String,
      messageIds: (fields[2] as List?)?.cast<String>(),
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
      // Nullable on read: sessions written before pinning existed carry no
      // field 5, and a hard cast would throw on the first read of an old box.
      pinned: (fields[5] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ChatSessionRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.messageIds)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.pinned);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatSessionRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
