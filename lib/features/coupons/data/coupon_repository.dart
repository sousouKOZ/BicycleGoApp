import '../domain/coupon.dart';

abstract class CouponRepository {
  Future<List<Coupon>> fetchCoupons();
}
