/// 图书相关数据模型
class BookInfo {
  final String bookUid;
  final String title;
  final String author;
  final String cover;
  final String intro;
  final String category;
  final String isbn;
  final String publisher;
  final String publishDate;
  final int totalPages;
  final int wordCount;

  BookInfo({
    required this.bookUid,
    required this.title,
    this.author = '',
    this.cover = '',
    this.intro = '',
    this.category = '',
    this.isbn = '',
    this.publisher = '',
    this.publishDate = '',
    this.totalPages = 0,
    this.wordCount = 0,
  });

  factory BookInfo.fromJson(Map<String, dynamic> json) {
    return BookInfo(
      bookUid: json['bookUid'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      cover: json['cover'] ?? '',
      intro: json['intro'] ?? '',
      category: json['category'] ?? '',
      isbn: json['isbn'] ?? '',
      publisher: json['publisher'] ?? '',
      publishDate: json['publishDate'] ?? '',
      totalPages: json['totalPages'] ?? 0,
      wordCount: json['wordCount'] ?? 0,
    );
  }
}

/// 书架图书（含阅读状态）
class ShelfBook {
  final BookInfo book;
  final int status; // 1:想读 2:在读 3:已读
  final int currentPage;
  final int rating;
  final String note;
  final String addedAt;

  ShelfBook({
    required this.book,
    this.status = 1,
    this.currentPage = 0,
    this.rating = 0,
    this.note = '',
    this.addedAt = '',
  });

  factory ShelfBook.fromJson(Map<String, dynamic> json) {
    return ShelfBook(
      book: BookInfo.fromJson(json),
      status: json['status'] ?? 1,
      currentPage: json['currentPage'] ?? 0,
      rating: json['rating'] ?? 0,
      note: json['note'] ?? '',
      addedAt: json['addedAt'] ?? '',
    );
  }

  double get progress {
    if (book.totalPages <= 0) return 0;
    return (currentPage / book.totalPages).clamp(0.0, 1.0);
  }

  String get statusText {
    switch (status) {
      case 1:
        return '想读';
      case 2:
        return '在读';
      case 3:
        return '已读';
      default:
        return '想读';
    }
  }
}
