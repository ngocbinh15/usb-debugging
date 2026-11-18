package dev.usbtoggle.app_usb;

import android.os.Bundle;

interface ICacheTrimmer {
    void destroy() = 16777114;
    Bundle trim() = 1;
}
