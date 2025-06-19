import 'package:flutter/material.dart';
import 'package:web_app/services/cart_repository.dart';
import '../models/item.dart';

class cartButton extends StatefulWidget {
  final Item item;
  const cartButton({super.key, required this.item});

  @override
  _cartButtonState createState() => _cartButtonState();
}

class _cartButtonState extends State<cartButton> {
  bool _iscarted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkcartStatus();
  }

  Future<void> _checkcartStatus() async {
    setState(() {
      _isLoading = true;
    });

    final iscarted = await cartRepository.instance.isItemcarted(widget.item.id);

    if (mounted) {
      setState(() {
        _iscarted = iscarted;
        _isLoading = false;
      });
    }
  }

  Future<void> _togglecart() async {
    setState(() {
      _isLoading = true;
    });

    bool success;
    if (_iscarted) {
      success = await cartRepository.instance.removecart(widget.item.id);
    } else {
      success = await cartRepository.instance.cartItem(widget.item);
    }

    if (success && mounted) {
      setState(() {
        _iscarted = !_iscarted;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : Icon(
              _iscarted ? Icons.shopping_cart : Icons.add,
              color: const Color(0xFFB37B5F),
            ),
      onPressed: _isLoading ? null : _togglecart,
    );
  }
}
