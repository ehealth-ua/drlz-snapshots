-ifndef(MRS_Ingredient).
-define(MRS_Ingredient, true).

-record('Ingredient', {
  id = [],
  inn_type = [],
  name_en = [],
  name_ua = [],
  reason = [],
  source_list_id = [],
  source_term_id = [],
  status = [],
  version = [],
  createdAt = [],
  updatedAt = []
}).

-endif.
