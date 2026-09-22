package com.fuzzzycore.seal

import android.Manifest
import android.app.Activity
import android.app.DownloadManager
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException

/**
 * The files the app produces (a fuzzed `.fuzz` on send, the unfuzzed file on
 * receive) land in `Downloads/Fuzzzy Ink/<chat name>/`, where the user finds
 * them with any file manager, and are opened, shown and shared from there by
 * content URI (T-0366).
 *
 * API 29+ writes through MediaStore (no storage permission); API 24–28 writes
 * the public Downloads folder directly and needs WRITE_EXTERNAL_STORAGE, which
 * the Dart side requests when `permissionDenied` comes back.
 */
class UserFiles(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.fuzzzycore.seal/user_files"
        private const val ROOT_FOLDER = "Fuzzzy Ink"
        private const val BINARY_MIME_TYPE = "application/octet-stream"
        private const val EXTERNAL_DOCUMENTS_AUTHORITY = "com.android.externalstorage.documents"
    }

    private class PermissionDenied : Exception("WRITE_EXTERNAL_STORAGE is not granted")

    private val fileProviderAuthority get() = "${activity.packageName}.userfiles"

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "saveToDownloads" -> result.success(
                    saveToDownloads(
                        sourcePath = call.argument<String>("sourcePath")!!,
                        chatName = call.argument<String>("chatName")!!,
                    )
                )
                "showInFiles" -> result.success(showInFiles(call.argument<String>("path")!!))
                "openFile" -> {
                    openFile(call.argument<String>("path")!!, call.argument<String>("mimeType"))
                    result.success(null)
                }
                "shareFile" -> {
                    shareFile(call.argument<String>("path")!!, call.argument<String>("mimeType"))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: PermissionDenied) {
            result.error("permissionDenied", e.message, null)
        } catch (e: FileNotFoundException) {
            result.error("notFound", e.message, null)
        } catch (e: ActivityNotFoundException) {
            result.error("noHandler", e.message, null)
        } catch (e: Exception) {
            result.error("failed", e.toString(), null)
        }
    }

    // ---------------------------------------------------------------------
    // Landing the file
    // ---------------------------------------------------------------------

    /** Moves [sourcePath] into `Downloads/Fuzzzy Ink/<chatName>/` and answers the public path (and the MediaStore URI on API 29+). */
    private fun saveToDownloads(sourcePath: String, chatName: String): Map<String, String?> {
        val source = File(sourcePath)
        if (!source.isFile) throw FileNotFoundException(sourcePath)
        val displayName = source.name
        val mimeType = mimeTypeFor(displayName)

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveThroughMediaStore(source, displayName, chatName, mimeType)
        } else {
            saveToLegacyDownloads(source, displayName, chatName, mimeType)
        }
    }

    private fun saveThroughMediaStore(
        source: File,
        displayName: String,
        chatName: String,
        mimeType: String,
    ): Map<String, String?> {
        val resolver = activity.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                "${Environment.DIRECTORY_DOWNLOADS}${File.separator}$ROOT_FOLDER${File.separator}$chatName",
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("MediaStore refused $displayName")

        try {
            resolver.openOutputStream(uri)!!.use { output ->
                source.inputStream().use { input -> input.copyTo(output) }
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }

        source.delete()
        return mapOf("path" to (pathOf(uri) ?: publicPathOf(chatName, displayName)), "uri" to uri.toString())
    }

    private fun saveToLegacyDownloads(
        source: File,
        displayName: String,
        chatName: String,
        mimeType: String,
    ): Map<String, String?> {
        val granted = activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        if (granted != PackageManager.PERMISSION_GRANTED) throw PermissionDenied()

        val folder = File(publicPathOf(chatName, displayName)).parentFile!!
        folder.mkdirs()
        val target = uniqueIn(folder, displayName)
        source.copyTo(target)
        source.delete()
        MediaScannerConnection.scanFile(activity, arrayOf(target.path), arrayOf(mimeType), null)
        return mapOf("path" to target.path, "uri" to null)
    }

    private fun publicPathOf(chatName: String, displayName: String): String =
        File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "$ROOT_FOLDER${File.separator}$chatName${File.separator}$displayName",
        ).path

    /** `name (1).ext`, `name (2).ext`, … like MediaStore does on a clash. */
    private fun uniqueIn(folder: File, displayName: String): File {
        var candidate = File(folder, displayName)
        if (!candidate.exists()) return candidate
        val dot = displayName.indexOf('.')
        val stem = if (dot > 0) displayName.substring(0, dot) else displayName
        val extension = if (dot > 0) displayName.substring(dot) else ""
        var n = 1
        while (candidate.exists()) {
            candidate = File(folder, "$stem ($n)$extension")
            n++
        }
        return candidate
    }

    private fun pathOf(uri: Uri): String? {
        @Suppress("DEPRECATION")
        val column = MediaStore.MediaColumns.DATA
        activity.contentResolver.query(uri, arrayOf(column), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0)
        }
        return null
    }

    // ---------------------------------------------------------------------
    // Reaching the file again
    // ---------------------------------------------------------------------

    /** A `.fuzz` (or any unknown extension) travels as a plain binary so every target app accepts it. */
    private fun mimeTypeFor(displayName: String): String {
        val extension = displayName.substringAfterLast('.', "").lowercase()
        if (extension.isEmpty()) return BINARY_MIME_TYPE
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: BINARY_MIME_TYPE
    }

    /**
     * A content URI another app can be granted: the app's own FileProvider
     * for a file this app can read (Downloads on API 30+, the legacy public
     * folder, anything under the app's private area is first staged in the
     * cache), the MediaStore row otherwise (API 29, where a file this app
     * owns in Downloads is not readable by path).
     */
    private fun contentUriFor(path: String): Uri {
        val file = File(path)
        if (file.canRead()) {
            return try {
                FileProvider.getUriForFile(activity, fileProviderAuthority, file)
            } catch (_: IllegalArgumentException) {
                FileProvider.getUriForFile(activity, fileProviderAuthority, stageInCache(file))
            }
        }
        return mediaStoreUriFor(path) ?: throw FileNotFoundException(path)
    }

    private fun stageInCache(file: File): File {
        val staging = File(activity.cacheDir, "user_files").apply { mkdirs() }
        val staged = File(staging, file.name)
        file.copyTo(staged, overwrite = true)
        return staged
    }

    private fun mediaStoreUriFor(path: String): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        @Suppress("DEPRECATION")
        val column = MediaStore.MediaColumns.DATA
        activity.contentResolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.MediaColumns._ID),
            "$column = ?",
            arrayOf(path),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cursor.getLong(0))
            }
        }
        return null
    }

    /**
     * Opens the folder the file is in. First the exact `Downloads/Fuzzy
     * Chat/<chat>` folder in the system file manager (DocumentsUI, Samsung My
     * Files), then the Downloads app; answers which one opened. A path outside
     * the public Downloads folder (a row from before T-0366) has no folder a
     * file manager can show and is reported as `noHandler`.
     */
    private fun showInFiles(path: String): String {
        val downloadsRoot = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).path
        val folder = File(path).parent ?: throw ActivityNotFoundException("no folder for $path")
        if (!folder.startsWith(downloadsRoot)) throw ActivityNotFoundException("$path is not in Downloads")

        val relativeFolder = Environment.DIRECTORY_DOWNLOADS + folder.removePrefix(downloadsRoot)
        val folderUri = DocumentsContract.buildDocumentUri(EXTERNAL_DOCUMENTS_AUTHORITY, "primary:$relativeFolder")
        val openFolder = Intent(Intent.ACTION_VIEW)
            .setDataAndType(folderUri, DocumentsContract.Document.MIME_TYPE_DIR)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        try {
            activity.startActivity(openFolder)
            return "folder"
        } catch (_: ActivityNotFoundException) {
        } catch (_: SecurityException) {
        }

        activity.startActivity(Intent(DownloadManager.ACTION_VIEW_DOWNLOADS))
        return "downloads"
    }

    private fun openFile(path: String, mimeType: String?) {
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(contentUriFor(path), mimeType ?: mimeTypeFor(File(path).name))
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        activity.startActivity(intent)
    }

    private fun shareFile(path: String, mimeType: String?) {
        val uri = contentUriFor(path)
        val type = mimeType ?: mimeTypeFor(File(path).name)
        val send = Intent(Intent.ACTION_SEND)
            .setType(type)
            .putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        // The grant must ride on the ClipData too, or a chooser target on
        // some OEM builds sees the URI without permission.
        send.clipData = ClipData.newUri(activity.contentResolver, File(path).name, uri)
        activity.startActivity(Intent.createChooser(send, null))
    }
}
