document.addEventListener("DOMContentLoaded", function () {
    initClientFilters();

    function initClientFilters() {
        document.querySelectorAll("[data-client-table]").forEach(function (table) {
            const key = table.dataset.clientTable;
            if (!key) return;

            const search = document.querySelector(`[data-client-search="${key}"]`);
            const filters = Array.from(document.querySelectorAll(`[data-client-filter="${key}"]`));
            const rows = Array.from(table.querySelectorAll("tbody tr[data-search]"));

            function apply() {
                const keyword = (search?.value || "").trim().toLocaleLowerCase("vi");

                for (const row of rows) {
                    const text = (row.dataset.search || "").toLocaleLowerCase("vi");
                    let visible = !keyword || text.includes(keyword);

                    for (const filter of filters) {
                        const field = filter.dataset.field;
                        const value = filter.value;
                        if (!value || !field) continue;
                        if ((row.dataset[field] || "") !== value) visible = false;
                    }

                    row.classList.toggle("admin-filter-hidden", !visible);
                }
            }

            search?.addEventListener("input", apply);
            filters.forEach(filter => filter.addEventListener("change", apply));
        });
    }
});
