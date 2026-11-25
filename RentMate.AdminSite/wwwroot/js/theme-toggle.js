// Nút chuyển sáng / tối (Tabler dùng thuộc tính data-bs-theme trên thẻ html), nhớ lựa chọn trong trình duyệt
(function () {
    function apply(theme) {
        if (theme === "dark") document.documentElement.setAttribute("data-bs-theme", "dark");
        else document.documentElement.removeAttribute("data-bs-theme");
    }

    document.addEventListener("click", function (event) {
        const button = event.target.closest("[data-theme-toggle]");
        if (!button) return;

        const next = document.documentElement.getAttribute("data-bs-theme") === "dark" ? "light" : "dark";
        apply(next);
        try { localStorage.setItem("rm-theme", next); } catch (e) { }
    });
})();
