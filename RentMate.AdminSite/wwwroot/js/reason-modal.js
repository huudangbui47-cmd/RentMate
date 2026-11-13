// Modal nhập lý do (từ chối đồ, từ chối nạp/rút...).
// Nút mở modal có data-id và data-name; modal có input name="id" và phần tử [data-fill-name].
document.addEventListener('show.bs.modal', function (event) {
    var modal = event.target;
    var button = event.relatedTarget;

    if (!button || !modal.hasAttribute('data-reason-modal')) return;

    var idInput = modal.querySelector('input[name="id"]');
    if (idInput) idInput.value = button.getAttribute('data-id') || '';

    modal.querySelectorAll('[data-fill-name]').forEach(function (el) {
        el.textContent = button.getAttribute('data-name') || '';
    });

    var reason = modal.querySelector('textarea');
    if (reason) reason.value = '';
});
