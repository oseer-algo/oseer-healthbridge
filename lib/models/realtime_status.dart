// lib/models/realtime_status.dart

/// Represents the granular state of the real-time connection.
enum RealtimeStatus {
  /// Not connected and not attempting to connect.
  disconnected,

  /// Actively attempting to establish a connection.
  connecting,

  /// Successfully subscribed and listening for events.
  subscribed,

  /// Connection was lost and is now attempting to reconnect with a backoff.
  retrying,

  /// A persistent, unrecoverable error occurred (e.g., auth failure).
  error,

  /// A specific network error occurred (e.g., DNS lookup failed, no internet).
  networkError,
}
