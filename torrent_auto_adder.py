import os
import subprocess
import logging
import bencodepy
import qbittorrentapi
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

# ==== CONFIGURATION ====

QBIT_HOST = "localhost"
QBIT_PORT = 8080
QBIT_USER = "admin"
QBIT_PASS = "adminadmin"

TORRENT_DIR = "./bt_files"
REMOTE_HOST = "mediahost"
SSH_USER = "your_ssh_user"
SSH_PASS = "your_ssh_password"

REMOTE_BASE_DIR = "/mnt/media"
LOCAL_BASE_DIR = "/mnt/media"

MAX_WORKERS = 10

# ==== LOGGING SETUP ====

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("torrent_import.log", mode='a'),
        logging.StreamHandler()
    ]
)

def log(msg_type, message):
    """
    Log a message with a formatted timestamp and message type.

    Args:
        msg_type (str): The type of the log message (e.g., INFO, WARNING, SUCCESS).
        message (str): The content of the log message.
    """
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    logging.info(f"* [{timestamp}] [{msg_type.upper()}] {message}")

# ==== SSH UTILITIES ====

def ssh_list_top_dirs():
    """
    Lists the top-level directories from the remote SSH media base path.

    Returns:
        list[str]: List of directory names (e.g., ["Movies", "Books", ...]).
    """
    try:
        cmd = [
            "sshpass", "-p", SSH_PASS,
            "ssh", f"{SSH_USER}@{REMOTE_HOST}",
            f"find {REMOTE_BASE_DIR} -mindepth 1 -maxdepth 1 -type d -printf '%f\n'"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        dirs = result.stdout.strip().splitlines()
        log("INFO", f"Retrieved {len(dirs)} categories from remote host: {dirs}")
        return dirs
    except Exception as e:
        logging.error(f"[ERROR] Could not list directories via SSH: {e}")
        return []

def ssh_path_exists(remote_path):
    """
    Check if a path exists on the remote SSH host.

    Args:
        remote_path (str): Full path to check on the remote host.

    Returns:
        bool: True if the path exists, False otherwise.
    """
    try:
        result = subprocess.run([
            "sshpass", "-p", SSH_PASS,
            "ssh", f"{SSH_USER}@{REMOTE_HOST}",
            f"test -e '{remote_path}' && echo OK || echo MISSING"
        ], capture_output=True, text=True, timeout=5)
        return "OK" in result.stdout
    except Exception as e:
        logging.error(f"[ERROR] SSH error while checking path {remote_path}: {e}")
        return False

# ==== TORRENT METADATA ====

def get_info_name(torrent_path):
    """
    Extract the `info.name` from a .torrent file.

    Args:
        torrent_path (str): Path to the .torrent file.

    Returns:
        str or None: The extracted info.name or None if parsing fails.
    """
    try:
        with open(torrent_path, "rb") as f:
            data = bencodepy.decode(f.read())
            return data[b'info'][b'name'].decode()
    except Exception as e:
        logging.error(f"[ERROR] Failed to parse {torrent_path}: {e}")
        return None

# ==== TORRENT HANDLING ====

def determine_remote_category(torrent_file, torrent_name, categories):
    """
    Determine the matching category (top-level folder) for a given torrent name.

    Args:
        torrent_file (str): Name of the .torrent file.
        torrent_name (str): Parsed info.name from the torrent.
        categories (list[str]): List of available remote categories.

    Returns:
        tuple[str or None, str or None]: (matched category name, full remote path) or (None, None)
    """
    for category in categories:
        remote_path = f"{REMOTE_BASE_DIR}/{category}/{torrent_name}"
        if ssh_path_exists(remote_path):
            log("INFO", f"Found remote path {torrent_file} {torrent_name} -> {remote_path}")
            return category, remote_path
    log("WARNING", f"Did not find remote path. Adding torrent anyway {torrent_file} {torrent_name} -> [no match]")
    return None, None

def add_torrent(client, torrent_path, torrent_file, torrent_name, save_path):
    """
    Add a torrent to qBittorrent using the API.

    Args:
        client (qbittorrentapi.Client): Authenticated qBittorrent client.
        torrent_path (str): Path to the .torrent file.
        torrent_file (str): Filename of the torrent.
        torrent_name (str): info.name inside the torrent.
        save_path (str or None): Destination path to re-seed from.

    Returns:
        bool: True if the torrent was added successfully.
    """
    try:
        with open(torrent_path, 'rb') as tf:
            client.torrents_add(
                torrent_files=tf,
                save_path=save_path if save_path else None,
                auto_torrent_management=False,
                skip_checking=True,
                paused=False
            )
        log("SUCCESS", f"Successfully added torrent {torrent_file} {torrent_name} {save_path or '[no match]'}")
        return True
    except Exception as e:
        logging.error(f"[ERROR] Failed to add {torrent_file} {torrent_name}: {e}")
        return False

def process_torrent(client, fname, categories):
    """
    Process a single .torrent file: extract metadata, match remote folder, and add to qBittorrent.

    Args:
        client (qbittorrentapi.Client): Authenticated client.
        fname (str): Filename of the .torrent file.
        categories (list[str]): Remote categories from SSH.

    Returns:
        str: Status ('added', 'error', or 'skipped')
    """
    if not fname.endswith(".torrent"):
        return 'skipped'

    tpath = os.path.join(TORRENT_DIR, fname)
    info_name = get_info_name(tpath)
    if not info_name:
        return 'error'

    log("INFO", f"Processing file {fname} -> {info_name}")
    category, _ = determine_remote_category(fname, info_name, categories)
    local_path = os.path.join(LOCAL_BASE_DIR, category) if category else None
    result = add_torrent(client, tpath, fname, info_name, local_path)
    return 'added' if result else 'error'

# ==== MAIN ====

def main():
    """
    Main execution function. Authenticates with qBittorrent, fetches remote categories,
    and processes torrents in parallel with logging.
    """
    log("INFO", "===== Parallel Torrent Re-seed Import =====")

    # Connect to qBittorrent
    try:
        client = qbittorrentapi.Client(
            host=QBIT_HOST,
            port=QBIT_PORT,
            username=QBIT_USER,
            password=QBIT_PASS
        )
        client.auth_log_in()
        log("INFO", "Connected to qBittorrent Web API")
    except Exception as e:
        logging.error(f"[ERROR] Could not connect to qBittorrent: {e}")
        return

    # Fetch top-level remote folders
    categories = ssh_list_top_dirs()
    if not categories:
        logging.error("[ERROR] No categories found on remote server. Exiting.")
        return

    all_files = sorted(os.listdir(TORRENT_DIR))
    total = added = skipped = errored = 0

    # Process in parallel
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {
            executor.submit(process_torrent, client, fname, categories): fname
            for fname in all_files
        }

        for future in as_completed(futures):
            result = future.result()
            total += 1
            if result == 'added':
                added += 1
            elif result == 'skipped':
                skipped += 1
            else:
                errored += 1

    # Final summary
    log("INFO", "===== Torrent Import Summary =====")
    log("INFO", f"Total:   {total}")
    log("INFO", f"Added:   {added}")
    log("INFO", f"Skipped: {skipped}")
    log("INFO", f"Errored: {errored}")

if __name__ == "__main__":
    main()
