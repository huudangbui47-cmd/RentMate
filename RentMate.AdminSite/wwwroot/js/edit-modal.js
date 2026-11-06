// Modal sửa nhanh: nút có data-edit-modal="#id" và data-edit-values='{"Name": "..."}'
// sẽ điền dữ liệu vào form trong modal. Form gửi bằng fetch; lỗi hiện trong modal
// (giữ nguyên những gì đã nhập), thành công thì tải lại trang.
document.addEventListener("DOMContentLoaded", function () {
    document.querySelectorAll("[data-edit-modal]").forEach(function (button) {
        button.addEventListener("click", function () {
            const modalElement = document.querySelector(button.dataset.editModal);
            if (!modalElement) return;

            const form = modalElement.querySelector("form");
            const values = JSON.parse(button.dataset.editValues || "{}");

            form.reset();
            clearMessage(form);
            if (window.resetPasswordToggles) window.resetPasswordToggles(form);

            for (const [name, value] of Object.entries(values)) {
                const input = form.elements[name];
                if (input) input.value = value ?? "";
            }

            bootstrap.Modal.getOrCreateInstance(modalElement).show();
        });
    });

    document.querySelectorAll("form[data-edit-form]").forEach(function (form) {
        form.addEventListener("submit", async function (event) {
            event.preventDefault();
            clearMessage(form);

            const button = form.querySelector('button[type="submit"]');
            button.disabled = true;

            try {
                const response = await fetch(form.action, { method: "POST", body: new FormData(form) });
                const data = await response.json().catch(() => ({}));

                if (!response.ok) throw new Error(data.message || "Không thể lưu thay đổi.");

                window.location.reload();
            } catch (error) {
                showError(form, error.message);
                button.disabled = false;
            }
        });
    });

    function showError(form, message) {
        const box = form.querySelector("[data-edit-message]");
        if (!box) return;

        const alert = document.createElement("div");
        alert.className = "alert alert-danger py-2";
        alert.setAttribute("role", "alert");
        alert.textContent = message;
        box.replaceChildren(alert);
        if (window.autoDismissAlert) window.autoDismissAlert(alert);
    }

    function clearMessage(form) {
        form.querySelector("[data-edit-message]")?.replaceChildren();
    }
});
