// Nút con mắt trong ô mật khẩu: bấm để hiện / ẩn những gì đã nhập
document.addEventListener("click", function (event) {
    const button = event.target.closest(".rm-password-toggle");
    if (!button) return;

    const field = button.closest(".rm-password-field");
    const input = field?.querySelector("input");
    if (!input) return;

    const visible = input.type === "password";
    input.type = visible ? "text" : "password";
    field.classList.toggle("is-visible", visible);
    button.setAttribute("aria-label", visible ? "Ẩn mật khẩu" : "Hiện mật khẩu");
});

// Đưa các ô mật khẩu trong vùng chỉ định về trạng thái ẩn (dùng khi mở lại modal)
window.resetPasswordToggles = function (container) {
    container.querySelectorAll(".rm-password-field").forEach(function (field) {
        const input = field.querySelector("input");
        if (input) input.type = "password";
        field.classList.remove("is-visible");
    });
};
