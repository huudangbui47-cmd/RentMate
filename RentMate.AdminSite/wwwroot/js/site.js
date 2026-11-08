// Thông báo dạng toast nổi ở góc trên bên phải, không chiếm chỗ trong trang nên layout không bị đẩy.
// Dùng chung cho: TempData Success/Error, lỗi máy chủ trả về trong form (validation summary)
// và thông báo từ các modal (gọi window.showToast). Mỗi toast có nút đóng và tự ẩn sau 3 giây.
(function () {
    const AUTO_HIDE_MS = 3000;

    function getStack() {
        let stack = document.querySelector(".rm-toast-stack");

        if (!stack) {
            stack = document.createElement("div");
            stack.className = "rm-toast-stack";
            stack.setAttribute("aria-live", "polite");
            document.body.appendChild(stack);
        }

        return stack;
    }

    function hideToast(toast) {
        if (toast.classList.contains("rm-toast-hiding")) return;

        toast.classList.add("rm-toast-hiding");
        setTimeout(() => toast.remove(), 250);
    }

    // type: "success" hoặc "error"
    window.showToast = function (message, type) {
        if (!message) return;

        const isSuccess = type === "success";
        const toast = document.createElement("div");
        toast.className = `alert ${isSuccess ? "alert-success" : "alert-danger"}`;
        toast.setAttribute("role", isSuccess ? "status" : "alert");
        toast.textContent = message;

        const closeButton = document.createElement("button");
        closeButton.type = "button";
        closeButton.className = "btn-close rm-toast-close";
        closeButton.setAttribute("aria-label", "Đóng");
        closeButton.addEventListener("click", () => hideToast(toast));
        toast.appendChild(closeButton);

        getStack().appendChild(toast);
        setTimeout(() => hideToast(toast), AUTO_HIDE_MS);
    };

    document.addEventListener("DOMContentLoaded", function () {
        // TempData do máy chủ render sẵn
        document.querySelectorAll(".admin-toast").forEach(function (element) {
            window.showToast(element.textContent.trim(), element.classList.contains("alert-success") ? "success" : "error");
            element.remove();
        });

        // Lỗi máy chủ trong form (trùng email, trùng SĐT...): chuyển thành toast thay vì chèn vào form
        document.querySelectorAll(".validation-summary-errors").forEach(function (summary) {
            summary.querySelectorAll("li").forEach(function (item) {
                window.showToast(item.textContent.trim(), "error");
            });
            summary.remove();
        });
    });
})();
