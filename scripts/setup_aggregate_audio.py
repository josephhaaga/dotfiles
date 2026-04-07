#!/usr/bin/env python3
"""
Creates a macOS aggregate audio device that combines the built-in microphone
and BlackHole 2ch, enabling simultaneous recording of microphone input and
system audio (music, videos, FaceTime, etc.).

Requires BlackHole 2ch to be installed (e.g. via `brew install --cask blackhole-2ch`).
Uses the macOS CoreAudio API directly via ctypes — no additional dependencies needed.
"""

import ctypes
import ctypes.util
import sys

# ---------------------------------------------------------------------------
# CoreFoundation helpers
# ---------------------------------------------------------------------------

_cf = ctypes.cdll.LoadLibrary(ctypes.util.find_library("CoreFoundation"))

_cf.CFStringCreateWithCString.restype = ctypes.c_void_p
_cf.CFStringCreateWithCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint32]

_cf.CFStringGetLength.restype = ctypes.c_long
_cf.CFStringGetLength.argtypes = [ctypes.c_void_p]

_cf.CFStringGetCString.restype = ctypes.c_bool
_cf.CFStringGetCString.argtypes = [
    ctypes.c_void_p, ctypes.c_char_p, ctypes.c_long, ctypes.c_uint32
]

_cf.CFDictionaryCreate.restype = ctypes.c_void_p
_cf.CFDictionaryCreate.argtypes = [
    ctypes.c_void_p,
    ctypes.POINTER(ctypes.c_void_p),
    ctypes.POINTER(ctypes.c_void_p),
    ctypes.c_long,
    ctypes.c_void_p,
    ctypes.c_void_p,
]

_cf.CFArrayCreate.restype = ctypes.c_void_p
_cf.CFArrayCreate.argtypes = [
    ctypes.c_void_p,
    ctypes.POINTER(ctypes.c_void_p),
    ctypes.c_long,
    ctypes.c_void_p,
]

_cf.CFRelease.restype = None
_cf.CFRelease.argtypes = [ctypes.c_void_p]

_cf.CFNumberCreate.restype = ctypes.c_void_p
_cf.CFNumberCreate.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]

# kCFAllocatorDefault = NULL, kCFStringEncodingUTF8 = 0x08000100
kCFStringEncodingUTF8 = 0x08000100
kCFNumberSInt32Type = 3


def _cfstr(s: str) -> ctypes.c_void_p:
    return _cf.CFStringCreateWithCString(None, s.encode("utf-8"), kCFStringEncodingUTF8)


def _cfstr_to_str(cfstr_ptr) -> str:
    if not cfstr_ptr:
        return ""
    length = _cf.CFStringGetLength(cfstr_ptr)
    buf = ctypes.create_string_buffer((length + 1) * 4)
    _cf.CFStringGetCString(cfstr_ptr, buf, len(buf), kCFStringEncodingUTF8)
    return buf.value.decode("utf-8")


# ---------------------------------------------------------------------------
# CoreAudio helpers
# ---------------------------------------------------------------------------

_ca = ctypes.cdll.LoadLibrary(ctypes.util.find_library("CoreAudio"))

OSStatus = ctypes.c_int32
AudioObjectID = ctypes.c_uint32

kAudioObjectSystemObject = AudioObjectID(1)
kAudioObjectPropertyScopeGlobal = 0x676C6F62  # 'glob'
kAudioObjectPropertyElementMaster = 0
kAudioHardwarePropertyDevices = 0x64657623  # 'dev#'
kAudioObjectPropertyName = 0x6C6E616D  # 'lnam'
kAudioDevicePropertyDeviceUID = 0x75696420  # 'uid '


class AudioObjectPropertyAddress(ctypes.Structure):
    _fields_ = [
        ("mSelector", ctypes.c_uint32),
        ("mScope", ctypes.c_uint32),
        ("mElement", ctypes.c_uint32),
    ]


_ca.AudioObjectGetPropertyDataSize.restype = OSStatus
_ca.AudioObjectGetPropertyDataSize.argtypes = [
    AudioObjectID,
    ctypes.POINTER(AudioObjectPropertyAddress),
    ctypes.c_uint32,
    ctypes.c_void_p,
    ctypes.POINTER(ctypes.c_uint32),
]

_ca.AudioObjectGetPropertyData.restype = OSStatus
_ca.AudioObjectGetPropertyData.argtypes = [
    AudioObjectID,
    ctypes.POINTER(AudioObjectPropertyAddress),
    ctypes.c_uint32,
    ctypes.c_void_p,
    ctypes.POINTER(ctypes.c_uint32),
    ctypes.c_void_p,
]

_ca.AudioHardwareCreateAggregateDevice.restype = OSStatus
_ca.AudioHardwareCreateAggregateDevice.argtypes = [
    ctypes.c_void_p,
    ctypes.POINTER(AudioObjectID),
]


def _get_property_data(obj_id, selector, scope=kAudioObjectPropertyScopeGlobal):
    addr = AudioObjectPropertyAddress(selector, scope, kAudioObjectPropertyElementMaster)
    size = ctypes.c_uint32(0)
    err = _ca.AudioObjectGetPropertyDataSize(obj_id, ctypes.byref(addr), 0, None, ctypes.byref(size))
    if err:
        return None, err
    buf = ctypes.create_string_buffer(size.value)
    err = _ca.AudioObjectGetPropertyData(obj_id, ctypes.byref(addr), 0, None, ctypes.byref(size), buf)
    if err:
        return None, err
    return buf, 0


def get_audio_devices() -> list[dict]:
    """Return a list of dicts with 'id', 'name', and 'uid' for every audio device."""
    buf, err = _get_property_data(kAudioObjectSystemObject, kAudioHardwarePropertyDevices)
    if err or buf is None:
        print(f"Error fetching audio devices: {err}", file=sys.stderr)
        return []

    n = len(buf) // ctypes.sizeof(AudioObjectID)
    device_ids = (AudioObjectID * n).from_buffer_copy(buf)
    devices = []
    for dev_id in device_ids:
        # Name
        addr_name = AudioObjectPropertyAddress(
            kAudioObjectPropertyName, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMaster
        )
        size = ctypes.c_uint32(ctypes.sizeof(ctypes.c_void_p))
        cfstr_name = ctypes.c_void_p(0)
        err = _ca.AudioObjectGetPropertyData(
            dev_id, ctypes.byref(addr_name), 0, None, ctypes.byref(size), ctypes.byref(cfstr_name)
        )
        name = _cfstr_to_str(cfstr_name) if not err else f"<device {dev_id}>"
        if cfstr_name:
            _cf.CFRelease(cfstr_name)

        # UID
        addr_uid = AudioObjectPropertyAddress(
            kAudioDevicePropertyDeviceUID, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMaster
        )
        size = ctypes.c_uint32(ctypes.sizeof(ctypes.c_void_p))
        cfstr_uid = ctypes.c_void_p(0)
        err = _ca.AudioObjectGetPropertyData(
            dev_id, ctypes.byref(addr_uid), 0, None, ctypes.byref(size), ctypes.byref(cfstr_uid)
        )
        uid = _cfstr_to_str(cfstr_uid) if not err else ""
        if cfstr_uid:
            _cf.CFRelease(cfstr_uid)

        devices.append({"id": dev_id.value, "name": name, "uid": uid})
    return devices


# ---------------------------------------------------------------------------
# Aggregate device constants (from CoreAudio/AudioHardwareBase.h)
# ---------------------------------------------------------------------------

AGGREGATE_DEVICE_NAME_KEY = "AggregateDevice_Name"
AGGREGATE_DEVICE_UID_KEY = "AggregateDevice_UID"
AGGREGATE_DEVICE_SUB_DEVICE_LIST_KEY = "AggregateDevice_SubDeviceList"
AGGREGATE_DEVICE_MASTER_SUB_DEVICE_KEY = "AggregateDevice_Master"
AGGREGATE_DEVICE_IS_PRIVATE_KEY = "AggregateDevice_Private"
AGGREGATE_DEVICE_IS_STACKED_KEY = "AggregateDevice_Stacked"
SUB_DEVICE_UID_KEY = "uid"

AGGREGATE_DEVICE_NAME = "Aggregate (Mic + System)"
AGGREGATE_DEVICE_UID = "com.josephhaaga.dotfiles.AggregateDevice.MicSystem"


def find_device(devices: list[dict], substring: str) -> dict | None:
    """Return the first device whose name contains *substring* (case-insensitive)."""
    for d in devices:
        if substring.lower() in d["name"].lower():
            return d
    return None


def device_already_exists(devices: list[dict]) -> bool:
    for d in devices:
        if d["uid"] == AGGREGATE_DEVICE_UID:
            return True
    return False


def create_aggregate_device(mic_uid: str, blackhole_uid: str) -> int:
    """Call AudioHardwareCreateAggregateDevice and return the new device ID, or 0 on failure.

    All intermediate CF objects are kept alive until after the API call so that
    the dictionaries / arrays hold valid pointers throughout.
    """
    # Keep every CF object in this list so they stay alive for the duration of the call
    _alive: list = []

    def cfstr_keep(s: str):
        ref = _cfstr(s)
        _alive.append(ref)
        return ref

    def cfnum_keep(n: int):
        val = ctypes.c_int32(n)
        ref = _cf.CFNumberCreate(None, kCFNumberSInt32Type, ctypes.byref(val))
        _alive.append(ref)
        return ref

    def make_sub_device_dict(uid: str):
        k = cfstr_keep(SUB_DEVICE_UID_KEY)
        v = cfstr_keep(uid)
        keys_arr = (ctypes.c_void_p * 1)(k)
        vals_arr = (ctypes.c_void_p * 1)(v)
        ref = _cf.CFDictionaryCreate(None, keys_arr, vals_arr, 1, None, None)
        _alive.append(ref)
        return ref

    # Sub-device list: mic first (it will be the clock master), then BlackHole
    sub_mic = make_sub_device_dict(mic_uid)
    sub_bh = make_sub_device_dict(blackhole_uid)
    sub_list_arr = (ctypes.c_void_p * 2)(sub_mic, sub_bh)
    sub_list = _cf.CFArrayCreate(None, sub_list_arr, 2, None)
    _alive.append(sub_list)

    # Top-level aggregate device description
    key_name    = cfstr_keep(AGGREGATE_DEVICE_NAME_KEY)
    val_name    = cfstr_keep(AGGREGATE_DEVICE_NAME)
    key_uid     = cfstr_keep(AGGREGATE_DEVICE_UID_KEY)
    val_uid     = cfstr_keep(AGGREGATE_DEVICE_UID)
    key_sublist = cfstr_keep(AGGREGATE_DEVICE_SUB_DEVICE_LIST_KEY)
    key_master  = cfstr_keep(AGGREGATE_DEVICE_MASTER_SUB_DEVICE_KEY)
    val_master  = cfstr_keep(mic_uid)
    key_private = cfstr_keep(AGGREGATE_DEVICE_IS_PRIVATE_KEY)
    val_private = cfnum_keep(0)  # 0 = not private (visible in system audio)

    desc_keys = (ctypes.c_void_p * 5)(key_name, key_uid, key_sublist, key_master, key_private)
    desc_vals = (ctypes.c_void_p * 5)(val_name, val_uid, sub_list,  val_master,  val_private)
    description = _cf.CFDictionaryCreate(None, desc_keys, desc_vals, 5, None, None)
    _alive.append(description)

    new_device_id = AudioObjectID(0)
    err = _ca.AudioHardwareCreateAggregateDevice(description, ctypes.byref(new_device_id))

    # Release everything now that the API has consumed the description
    for obj in _alive:
        if obj:
            _cf.CFRelease(obj)

    if err:
        print(f"AudioHardwareCreateAggregateDevice failed with error {err}", file=sys.stderr)
        return 0
    return new_device_id.value


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("Scanning audio devices…")
    devices = get_audio_devices()
    if not devices:
        print("No audio devices found — aborting.", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(devices)} device(s):")
    for d in devices:
        print(f"  [{d['id']:4d}] {d['name']!r}  uid={d['uid']!r}")

    if device_already_exists(devices):
        print(f"\nAggregate device '{AGGREGATE_DEVICE_NAME}' already exists — nothing to do.")
        sys.exit(0)

    # Locate BlackHole
    blackhole = find_device(devices, "BlackHole 2ch")
    if not blackhole:
        print(
            "\nBlackHole 2ch not found. Make sure it is installed:\n"
            "  brew install --cask blackhole-2ch",
            file=sys.stderr,
        )
        sys.exit(1)

    # Locate built-in microphone (prefer "MacBook" or "Built-in" mic)
    mic = (
        find_device(devices, "MacBook Pro Microphone")
        or find_device(devices, "MacBook Air Microphone")
        or find_device(devices, "Built-in Microphone")
        or find_device(devices, "Microphone")
    )
    if not mic:
        print(
            "\nCould not find a built-in microphone device. "
            "Please create the aggregate device manually in Audio MIDI Setup.",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"\nMicrophone  : {mic['name']!r}  (uid={mic['uid']!r})")
    print(f"BlackHole   : {blackhole['name']!r}  (uid={blackhole['uid']!r})")
    print(f"\nCreating aggregate device '{AGGREGATE_DEVICE_NAME}'…")

    new_id = create_aggregate_device(mic["uid"], blackhole["uid"])
    if new_id:
        print(f"✓ Aggregate device created (AudioObjectID={new_id}).")
        print(
            "\nTip: In your recording app (OBS, Audacity, QuickTime, etc.) select\n"
            f"  '{AGGREGATE_DEVICE_NAME}' as the input device to capture both\n"
            "  your microphone and all system audio simultaneously."
        )
    else:
        print("Failed to create aggregate device.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
