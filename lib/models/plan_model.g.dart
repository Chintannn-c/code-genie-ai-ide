// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlanStepAdapter extends TypeAdapter<PlanStep> {
  @override
  final int typeId = 2;

  @override
  PlanStep read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlanStep(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      status: fields[3] as PlanStepStatus,
      output: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PlanStep obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.output);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanStepAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlanModelAdapter extends TypeAdapter<PlanModel> {
  @override
  final int typeId = 3;

  @override
  PlanModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlanModel(
      id: fields[0] as String,
      goal: fields[1] as String,
      steps: (fields[2] as List).cast<PlanStep>(),
      createdAt: fields[3] as DateTime,
      isApproved: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PlanModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.goal)
      ..writeByte(2)
      ..write(obj.steps)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.isApproved);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlanStepStatusAdapter extends TypeAdapter<PlanStepStatus> {
  @override
  final int typeId = 1;

  @override
  PlanStepStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PlanStepStatus.pending;
      case 1:
        return PlanStepStatus.running;
      case 2:
        return PlanStepStatus.completed;
      case 3:
        return PlanStepStatus.failed;
      default:
        return PlanStepStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, PlanStepStatus obj) {
    switch (obj) {
      case PlanStepStatus.pending:
        writer.writeByte(0);
        break;
      case PlanStepStatus.running:
        writer.writeByte(1);
        break;
      case PlanStepStatus.completed:
        writer.writeByte(2);
        break;
      case PlanStepStatus.failed:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanStepStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
