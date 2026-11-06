// Mọi thông báo (toast thành công/lỗi, lỗi trả về từ máy chủ trong form, thông báo trong modal)
// đều có nút đóng và tự ẩn sau 5 giây.
// Thông báo cần giữ lại cho người dùng đọc kỹ (vd. mật khẩu tạm) thì đánh dấu data-persistent.
(function () {
    const AUTO_HIDE_MS = 5000;

    function closeAlert(alert) {
        alert.classList.remove("show");
        alert.classList.add("rm-alert-hiding");
        setTimeout(() => alert.remove(), 250);
    }

    window.autoDismissAlert = function (alert) {
        if (!alert || alert.dataset.rmDismiss) return;
        alert.dataset.rmDismiss = "true";

        if (!alert.querySelector(".btn-close")) {
            const button = document.createElement("button");
            button.type = "button";
            button.className = "btn-close rm-alert-close";
            button.setAttribute("aria-label", "Đóng");
            button.addEventListener("click", () => closeAlert(alert));

            alert.classList.add("rm-alert-closable");
            alert.appendChild(button);
        }

        if (!alert.hasAttribute("data-persistent")) {
            setTimeout(() => closeAlert(alert), AUTO_HIDE_MS);
        }
    };

    document.addEventListener("DOMContentLoaded", function () {
        document
            .querySelectorAll(".admin-toast, .alert.validation-summary-errors")
            .forEach(window.autoDismissAlert);
    });
})();
