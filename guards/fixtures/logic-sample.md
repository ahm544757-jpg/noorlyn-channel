# عيّنة منطق — لا تُستخدم إلا في CI
**total_extracted_rows** | **6**
**classified_requirements** | **6**
**atomic_requirements** | **5**
**total_discoveries** | **5**
**routed_discoveries** | **5**
سجل المطالب `6cb33babaf44c58e552164e52630fa77e1f5ddd1e4b82f27162b8de338f1fafb`

| المصير | العدد |
|---|---|
| `in_plan` | 2 |
| `owner_package` | 1 |
| `representation_blocker` | 1 |
| `deferred_with_reason` | 1 |
| `out_of_scope_with_reason` | 1 |

| النوع | العدد | المعنى |
|---|---|---|
| `parent` | 1 | ترويسة |
| `member` | 1 | ابن |
| `standalone` | 4 | مستقل |

| المنطقة | المجموع | in_plan | غيره |
|---|---|---|---|
| A-قراءة-العربية | 2 | 2 | 0 |
| B-مخارج-وصفات | 1 | 0 | 1 |
| C-تجويد | 1 | 0 | 1 |
| Q-عام | 2 | 0 | 2 |

| القيمة | العدد |
|---|---|
| `verified_in_baseline` | 1 |
| `partial_or_adapter` | 0 |
| `missing_in_baseline` | 0 |

| المسار | الكل | منها مفتوح |
|---|---|---|
| `plan` | 1 | 1 |
| `owner` | 2 | 1 |
| `representation` | 1 | 1 |
| `knowledge_gap` | 1 | 1 |

| # | الاكتشاف | المسار | الحالة | السبب |
|---|---|---|---|---|
| د-٠١ | عيّنة خطة | `plan` | مفتوح | سبب |
| د-٠٢ | عيّنة مالك | `owner` | مفتوح | سبب |
| د-٠٣ | عيّنة تمثيل | `representation` | مفتوح | سبب |
| د-٠٤ | عيّنة فجوة | `knowledge_gap` | مفتوح | سبب |
| د-٠٥ | عيّنة مغلقة | `owner` | مُغلق بـ إ-٠٠٤ | سبب |
