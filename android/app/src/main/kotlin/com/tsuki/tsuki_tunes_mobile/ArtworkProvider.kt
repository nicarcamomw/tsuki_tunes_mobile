package com.tsuki.tsuki_tunes_mobile

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.FileNotFoundException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/// Album art for Android Auto's lists. Auto only shows artwork the app
/// serves itself (content:// URIs), not links on the internet, so this
/// fetches the cover once into the cache and hands Auto the file:
/// content://<applicationId>.artwork/art?u=<https cover URL>.
///
/// Only covers from Deezer's and Spotify's image servers are fetched, so
/// other apps can't use it to download anything else.
class ArtworkProvider : ContentProvider() {

    companion object {
        private val allowedHosts = listOf("dzcdn.net", "deezer.com", "scdn.co", "spotifycdn.com")
        private const val maxFiles = 300
        private const val timeoutMs = 8000
    }

    override fun onCreate(): Boolean = true

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        val remote = uri.getQueryParameter("u") ?: throw FileNotFoundException("no url")
        val parsed = Uri.parse(remote)
        val host = parsed.host ?: ""
        if (parsed.scheme != "https" || allowedHosts.none { host == it || host.endsWith(".$it") }) {
            throw FileNotFoundException("not an artwork url")
        }
        val dir = File(context!!.cacheDir, "auto_art").apply { mkdirs() }
        val file = File(dir, sha1(remote))
        if (!file.exists()) {
            val tmp = File(dir, "${file.name}.tmp")
            val connection = URL(remote).openConnection() as HttpURLConnection
            try {
                connection.connectTimeout = timeoutMs
                connection.readTimeout = timeoutMs
                connection.inputStream.use { input -> tmp.outputStream().use { input.copyTo(it) } }
                if (!tmp.renameTo(file)) throw FileNotFoundException("cache write failed")
            } catch (e: Exception) {
                tmp.delete()
                throw FileNotFoundException("download failed: ${e.message}")
            } finally {
                connection.disconnect()
            }
            prune(dir)
        }
        file.setLastModified(System.currentTimeMillis())
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    /// Keeps the newest [maxFiles] covers.
    private fun prune(dir: File) {
        val files = dir.listFiles()?.filter { !it.name.endsWith(".tmp") } ?: return
        if (files.size <= maxFiles) return
        files.sortedBy { it.lastModified() }.take(files.size - maxFiles).forEach { it.delete() }
    }

    private fun sha1(text: String): String =
        MessageDigest.getInstance("SHA-1").digest(text.toByteArray())
            .joinToString("") { "%02x".format(it) }

    override fun getType(uri: Uri): String = "image/jpeg"

    override fun query(
        uri: Uri, projection: Array<out String>?, selection: String?,
        selectionArgs: Array<out String>?, sortOrder: String?,
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?,
    ): Int = 0
}
