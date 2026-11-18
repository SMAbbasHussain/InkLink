/// How a drag on empty canvas with the Select tool collects elements.
enum CanvasSelectionMode {
  /// Rectangular marquee: elements intersecting the dragged box are selected.
  marquee,

  /// Freehand lasso: elements whose centre (or whole box) falls inside the
  /// drawn loop are selected.
  lasso,
}
