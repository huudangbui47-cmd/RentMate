document.addEventListener("DOMContentLoaded", function () {
    const modalElement = document.getElementById("accountProfileModal");
    if (!modalElement) return;

    const profileForm = document.getElementById("accountProfileForm");
    const passwordForm = document.getElementById("accountPasswordForm");
    const avatarForm = document.getElementById("accountAvatarForm");
    const avatarInput = document.getElementById("profileAvatarInput");
    const avatarChooseButton = document.getElementById("profileAvatarChoose");
    const avatarRemoveButton = document.getElementById("profileAvatarRemove");
    const avatarPreview = document.getElementById("profileAvatarPreview");
    const profileMessage = document.getElementById("profileMessage");
    const passwordMessage = document.getElementById("passwordMessage");

    let currentFullName = "";
    let currentAvatarUrl = null;

    modalElement.addEventListener("show.bs.modal", loadProfile);

    profileForm.addEventListener("submit", async function (event) {
        event.preventDefault();
        clearMessage(profileMessage);

        const button = profileForm.querySelector('button[type="submit"]');
        setButtonLoading(button, true);

        try {
            const response = await fetch("/Account/UpdateProfile", { method: "POST", body: new FormData(profileForm) });
            const data = await response.json();

            if (!response.ok) throw new Error(data.message || "Không thể cập nhật thông tin.");

            currentFullName = data.fullName || "";
            document.getElementById("currentUserName").textContent = currentFullName;
            renderAvatars();
            showSuccess(profileMessage, data.message || "Cập nhật thành công.");
        } catch (error) {
            showError(profileMessage, error.message);
        } finally {
            setButtonLoading(button, false);
        }
    });

    passwordForm.addEventListener("submit", async function (event) {
        event.preventDefault();
        clearMessage(passwordMessage);

        const button = passwordForm.querySelector('button[type="submit"]');
        setButtonLoading(button, true);

        try {
            const response = await fetch("/Account/ChangePasswordAjax", { method: "POST", body: new FormData(passwordForm) });
            const data = await response.json();

            if (!response.ok) throw new Error(data.message || "Không thể đổi mật khẩu.");
            passwordForm.reset();
            showSuccess(passwordMessage, data.message || "Đổi mật khẩu thành công.");
        } catch (error) {
            showError(passwordMessage, error.message);
        } finally {
            setButtonLoading(button, false);
        }
    });

    // Chọn ảnh xong là tải lên ngay
    avatarChooseButton.addEventListener("click", () => avatarInput.click());

    avatarInput.addEventListener("change", async function () {
        if (!avatarInput.files.length) return;

        await submitAvatar("/Account/UploadAvatar", new FormData(avatarForm), avatarChooseButton);
        avatarInput.value = "";
    });

    avatarRemoveButton.addEventListener("click", async function () {
        if (!confirm("Gỡ ảnh đại diện?")) return;

        const formData = new FormData();
        formData.append("__RequestVerificationToken", avatarForm.querySelector('input[name="__RequestVerificationToken"]').value);

        await submitAvatar("/Account/RemoveAvatar", formData, avatarRemoveButton);
    });

    async function submitAvatar(url, formData, button) {
        clearMessage(profileMessage);
        setButtonLoading(button, true);

        try {
            const response = await fetch(url, { method: "POST", body: formData });
            const data = await response.json().catch(() => ({}));

            if (!response.ok) throw new Error(data.message || "Không thể cập nhật ảnh đại diện.");

            currentAvatarUrl = data.avatarUrl || null;
            renderAvatars();
            showSuccess(profileMessage, data.message || "Cập nhật ảnh đại diện thành công.");
        } catch (error) {
            showError(profileMessage, error.message);
        } finally {
            setButtonLoading(button, false);
        }
    }

    async function loadProfile() {
        clearMessage(profileMessage);
        clearMessage(passwordMessage);
        passwordForm.reset();
        if (window.resetPasswordToggles) window.resetPasswordToggles(passwordForm);

        try {
            const response = await fetch("/Account/Profile");
            const data = await response.json();

            if (!response.ok) throw new Error(data.message || "Không thể tải thông tin tài khoản.");

            document.getElementById("profileFullName").value = data.fullName || "";
            document.getElementById("profileEmail").value = data.email || "";
            document.getElementById("profilePhone").value = data.phoneNumber || "";
            document.getElementById("profileRole").value = data.roleName || "";

            currentFullName = data.fullName || "";
            currentAvatarUrl = data.avatarUrl || null;
            renderAvatars();
        } catch (error) {
            showError(profileMessage, error.message);
        }
    }

    // Vẽ lại avatar ở modal và ở sidebar: có ảnh thì hiện ảnh, không thì hiện chữ cái đầu
    function renderAvatars() {
        const initial = currentFullName ? currentFullName.charAt(0).toUpperCase() : "U";
        const sidebarAvatar = document.getElementById("currentUserAvatar");

        for (const element of [avatarPreview, sidebarAvatar]) {
            if (!element) continue;

            if (currentAvatarUrl) {
                const image = document.createElement("img");
                image.src = currentAvatarUrl;
                image.alt = "Ảnh đại diện";
                element.replaceChildren(image);
            } else {
                element.replaceChildren(document.createTextNode(initial));
            }
        }

        avatarRemoveButton.classList.toggle("d-none", !currentAvatarUrl);
    }

    function showError(element, message) {
        showMessage(element, "alert-danger", "alert", message);
    }

    function showSuccess(element, message) {
        showMessage(element, "alert-success", "status", message);
    }

    function showMessage(element, alertClass, role, message) {
        const alert = document.createElement("div");
        alert.className = `alert ${alertClass} py-2`;
        alert.setAttribute("role", role);
        alert.textContent = message;
        element.replaceChildren(alert);

        if (window.autoDismissAlert) window.autoDismissAlert(alert);
    }

    function clearMessage(element) {
        element.replaceChildren();
    }

    function setButtonLoading(button, loading) {
        button.disabled = loading;

        if (loading) {
            button.dataset.originalText = button.textContent;
            button.textContent = "Đang xử lý...";
        } else if (button.dataset.originalText) {
            button.textContent = button.dataset.originalText;
        }
    }
});
