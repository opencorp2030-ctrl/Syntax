"""Authentification PAM minimale via ctypes (aucune dépendance externe)."""
import ctypes
import ctypes.util
from ctypes import CFUNCTYPE, POINTER, Structure, c_char_p, c_int, c_void_p, cast, sizeof

PAM_PROMPT_ECHO_OFF = 1
PAM_PROMPT_ECHO_ON = 2
PAM_SUCCESS = 0
PAM_RHOST = 4


class PamMessage(Structure):
    _fields_ = [("msg_style", c_int), ("msg", c_char_p)]


class PamResponse(Structure):
    _fields_ = [("resp", c_void_p), ("resp_retcode", c_int)]


CONV_FUNC = CFUNCTYPE(c_int, c_int, POINTER(POINTER(PamMessage)),
                      POINTER(POINTER(PamResponse)), c_void_p)


class PamConv(Structure):
    _fields_ = [("conv", CONV_FUNC), ("appdata_ptr", c_void_p)]


_libpam = ctypes.CDLL(ctypes.util.find_library("pam") or "libpam.so.0")
_libc = ctypes.CDLL(ctypes.util.find_library("c") or "libc.so.6")
_libc.calloc.restype = c_void_p
_libc.calloc.argtypes = [ctypes.c_size_t, ctypes.c_size_t]
_libc.strdup.restype = c_void_p
_libc.strdup.argtypes = [c_char_p]

_libpam.pam_start.restype = c_int
_libpam.pam_start.argtypes = [c_char_p, c_char_p, POINTER(PamConv), POINTER(c_void_p)]
_libpam.pam_authenticate.restype = c_int
_libpam.pam_authenticate.argtypes = [c_void_p, c_int]
_libpam.pam_acct_mgmt.restype = c_int
_libpam.pam_acct_mgmt.argtypes = [c_void_p, c_int]
_libpam.pam_set_item.restype = c_int
_libpam.pam_set_item.argtypes = [c_void_p, c_int, c_void_p]
_libpam.pam_end.restype = c_int
_libpam.pam_end.argtypes = [c_void_p, c_int]


def authenticate(username, password, service="syntax-portal", rhost=None):
    """Renvoie True si le couple utilisateur / mot de passe est valide."""
    if not username or not password or "\x00" in username or "\x00" in password:
        return False
    pw = password.encode("utf-8")

    @CONV_FUNC
    def conv(n, messages, responses, _appdata):
        addr = _libc.calloc(n, sizeof(PamResponse))
        if not addr:
            return 5  # PAM_BUF_ERR
        arr = cast(addr, POINTER(PamResponse))
        for i in range(n):
            if messages[i].contents.msg_style in (PAM_PROMPT_ECHO_OFF, PAM_PROMPT_ECHO_ON):
                arr[i].resp = _libc.strdup(pw)
            arr[i].resp_retcode = 0
        responses[0] = arr
        return PAM_SUCCESS

    handle = c_void_p()
    pc = PamConv(conv, None)
    rc = _libpam.pam_start(service.encode(), username.encode("utf-8"), ctypes.byref(pc),
                           ctypes.byref(handle))
    if rc != PAM_SUCCESS:
        return False
    try:
        if rhost:
            buf = ctypes.create_string_buffer(rhost.encode("ascii", "replace"))
            _libpam.pam_set_item(handle, PAM_RHOST, cast(buf, c_void_p))
        rc = _libpam.pam_authenticate(handle, 0)
        if rc == PAM_SUCCESS:
            rc = _libpam.pam_acct_mgmt(handle, 0)
        return rc == PAM_SUCCESS
    finally:
        _libpam.pam_end(handle, rc)
