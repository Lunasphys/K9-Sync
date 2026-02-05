part of 'shell_bloc.dart';

sealed class ShellEvent extends Equatable {
  const ShellEvent();

  @override
  List<Object?> get props => [];
}

final class ShellTabSelected extends ShellEvent {
  final int index;

  const ShellTabSelected(this.index);

  @override
  List<Object?> get props => [index];
}
