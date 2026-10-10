import 'package:flutter/material.dart';

/// The ways to play with friends.
enum FriendsMode {
  /// Everyone on this device, passing it round.
  passAndPlay,

  /// This device hosts; friends join from theirs on the same network.
  host,

  /// Join a game hosted on another device on the same network.
  join,
}

/// Asks how to play with friends. Completes with the choice, or `null` if
/// the player closes it.
Future<FriendsMode?> showPlayWithFriends(BuildContext context) =>
    showDialog<FriendsMode>(
      context: context,
      builder: (context) => SimpleDialog(
        key: const Key('play-with-friends'),
        title: const Text('Play with friends'),
        children: [
          for (final (mode, icon, title, subtitle) in const [
            (
              FriendsMode.passAndPlay,
              Icons.swap_horiz,
              'On this device',
              'Pass it round between turns',
            ),
            (
              FriendsMode.host,
              Icons.wifi_tethering,
              'Host on Wi-Fi',
              'Friends join from their phones',
            ),
            (
              FriendsMode.join,
              Icons.login,
              'Join with a code',
              'From a friend hosting on the same Wi-Fi',
            ),
          ])
            ListTile(
              key: Key('friends-${mode.name}'),
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(subtitle),
              onTap: () => Navigator.of(context).pop(mode),
            ),
        ],
      ),
    );
