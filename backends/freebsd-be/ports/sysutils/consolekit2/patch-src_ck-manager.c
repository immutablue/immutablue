--- src/ck-manager.c.orig	2026-10-29 00:00:00 UTC
+++ src/ck-manager.c
@@ -3721,7 +3721,10 @@ get_session_from_id (CkManager   *manager,
                 return NULL;
         }
 
-        session = g_hash_table_lookup (manager->priv->sessions, arg_session_id);
+        /* gdm passes the object path GetSessionForCookie returned
+         * (/org/freedesktop/ConsoleKit/Session2); sessions are keyed by
+         * the bare id. */
+        session = g_hash_table_lookup (manager->priv->sessions, get_object_id_basename (arg_session_id));
 
         if (!CK_IS_SESSION (session)) {
                 return NULL;
@@ -3760,7 +3763,7 @@ dbus_activate_session_on_seat (ConsoleKitManager *ckma
                 return TRUE;
         }
 
-        seat = g_hash_table_lookup (manager->priv->seats, arg_seat_id);
+        seat = g_hash_table_lookup (manager->priv->seats, get_object_id_basename (arg_seat_id));
 
         if (!CK_IS_SEAT (seat)) {
                 throw_error (context, CK_MANAGER_ERROR_INVALID_INPUT, _("Invalid seat"));
