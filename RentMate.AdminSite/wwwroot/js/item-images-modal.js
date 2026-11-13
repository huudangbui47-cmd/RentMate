// Modal xem tất cả ảnh của một món đồ (trang Đồ cho thuê).
// Nút mở modal có data-name và data-images (mảng JSON các link ảnh).
document.addEventListener('show.bs.modal', function (event) {
    var modal = event.target;
    var button = event.relatedTarget;

    if (!button || modal.id !== 'itemImagesModal') return;

    modal.querySelector('[data-fill-name]').textContent = button.getAttribute('data-name') || '';

    var grid = modal.querySelector('[data-image-grid]');
    grid.innerHTML = '';

    var images = [];
    try { images = JSON.parse(button.getAttribute('data-images') || '[]'); } catch (e) { images = []; }

    images.forEach(function (src) {
        var link = document.createElement('a');
        link.href = src;
        link.target = '_blank';
        link.rel = 'noopener';

        var img = document.createElement('img');
        img.src = src;
        img.alt = '';
        img.loading = 'lazy';

        link.appendChild(img);
        grid.appendChild(link);
    });
});
