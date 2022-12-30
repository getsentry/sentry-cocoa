#ifndef MINIJSON_WRITER_H
#define MINIJSON_WRITER_H

#include <cstddef>
#include <iomanip>
#include <iterator>
#include <locale>
#include <ostream>
#include <string>
#include <utility>

#define MJW_CPP11_SUPPORTED __cplusplus > 199711L || _MSC_VER >= 1800

#if MJW_CPP11_SUPPORTED

#include <cmath>
#include <type_traits>
#define MJW_LIB_NS std
#define MJW_ISFINITE(X) std::isfinite(X)
#define MJW_STATIC_ASSERT(COND, MESSAGE) static_assert(COND, MESSAGE)

#else

#include <boost/type_traits/remove_cv.hpp>
#include <boost/type_traits/is_integral.hpp>
#include <boost/type_traits/is_same.hpp>
#include <boost/type_traits/is_floating_point.hpp>
#include <boost/math/special_functions/fpclassify.hpp>
#define MJW_LIB_NS boost
#define MJW_ISFINITE(X) boost::math::isfinite(X)
#define MJW_STATIC_ASSERT(COND, MESSAGE) BOOST_STATIC_ASSERT(COND)

#endif

namespace minijson
{

enum null_t
{
    null = 0
};

class writer_configuration
{
private:

    size_t m_nesting_level;
    bool m_pretty_printing;
    size_t m_indent_spaces;
    bool m_use_tabs;

public:

    explicit writer_configuration() :
        m_nesting_level(0),
        m_pretty_printing(false),
        m_indent_spaces(4),
        m_use_tabs(false)
    {
    }

    size_t nesting_level() const
    {
        return m_nesting_level;
    }

    writer_configuration increase_nesting_level() const
    {
        writer_configuration result = *this;
        result.m_nesting_level++;

        return result;
    }

    bool pretty_printing() const
    {
        return m_pretty_printing;
    }

    writer_configuration pretty_printing(bool value) const
    {
        writer_configuration result = *this;
        result.m_pretty_printing = value;

        return result;
    }

    size_t indent_spaces() const
    {
        return m_indent_spaces;
    }

    writer_configuration indent_spaces(size_t value) const
    {
        writer_configuration result = *this;
        result.m_indent_spaces = value;

        return result;
    }

    bool use_tabs() const
    {
        return m_use_tabs;
    }

    writer_configuration use_tabs(bool value) const
    {
        writer_configuration result = *this;
        result.m_use_tabs = value;

        return result;
    }
};

template<typename V, typename Enable = void>
struct default_value_writer;

template<typename InputIt>
void write_array(
        std::ostream& stream,
        InputIt begin, InputIt end,
        const writer_configuration& configuration = writer_configuration());

template<typename InputIt, typename ValueWriter>
void write_array(
        std::ostream& stream,
        InputIt begin, InputIt end,
        const ValueWriter& value_writer,
        const writer_configuration& configuration = writer_configuration());

namespace detail
{

template<bool>
struct enable_if;

template<>
struct enable_if<true>
{
    typedef void type;
};

template<typename InputIt>
struct get_value_type
{
    typedef typename MJW_LIB_NS::remove_cv<typename std::iterator_traits<InputIt>::value_type>::type type;
};

#if MJW_CPP11_SUPPORTED

template<size_t Rank>
struct overload_rank : overload_rank<Rank - 1>
{
};

template<>
struct overload_rank<0>
{
};

typedef overload_rank<63> call_ranked;

template<typename Functor>
struct two_or_three_args_functor
{
private:

    Functor functor;

    template<typename Arg1, typename Arg2, typename Arg3>
    auto operator_impl(Arg1&& arg1, Arg2&& arg2, Arg3&& arg3, overload_rank<1>)
        -> decltype(functor(std::forward<Arg1>(arg1), std::forward<Arg2>(arg2), std::forward<Arg3>(arg3)))
    {
        functor(std::forward<Arg1>(arg1), std::forward<Arg2>(arg2), std::forward<Arg3>(arg3));
    }

    template<typename Arg1, typename Arg2, typename Arg3>
    auto operator_impl(Arg1&& arg1, Arg2&& arg2, Arg3&&, overload_rank<0>)
        -> decltype(functor(std::forward<Arg1>(arg1), std::forward<Arg2>(arg2)))
    {
        functor(std::forward<Arg1>(arg1), std::forward<Arg2>(arg2));
    }

public:

    explicit two_or_three_args_functor(Functor functor) :
        functor(std::move(functor))
    {
    }

    template<typename Arg1, typename Arg2, typename Arg3>
    void operator()(Arg1&& arg1, Arg2&& arg2, Arg3&& arg3)
    {
        operator_impl(std::forward<Arg1>(arg1), std::forward<Arg2>(arg2), std::forward<Arg3>(arg3), call_ranked());
    }
};

#else

template<typename Functor>
struct two_or_three_args_functor : Functor
{
    mutable Functor functor;

    explicit two_or_three_args_functor(const Functor& functor) :
        Functor(functor),
        functor(functor)
    {
    }

    using Functor::operator();

    template<typename Arg1, typename Arg2, typename Arg3>
    void operator()(Arg1& arg1, Arg2& arg2, Arg3&) const
    {
        functor(arg1, arg2);
    }
};

template<typename R, typename X1, typename X2>
struct two_or_three_args_functor<R (*)(X1, X2)>
{
    typedef R (*Function)(X1, X2);

    Function function;

    explicit two_or_three_args_functor(Function function) :
        function(function)
    {
    }

    template<typename Arg1, typename Arg2, typename Arg3>
    void operator()(Arg1& arg1, Arg2& arg2, Arg3&) const
    {
        function(arg1, arg2);
    }
};

template<typename R, typename X1, typename X2, typename X3>
struct two_or_three_args_functor<R (*)(X1, X2, X3)>
{
    typedef R (*Function)(X1, X2, X3);

    Function function;

    explicit two_or_three_args_functor(Function function) :
        function(function)
    {
    }

    template<typename Arg1, typename Arg2, typename Arg3>
    void operator()(Arg1& arg1, Arg2& arg2, Arg3& arg3) const
    {
        function(arg1, arg2, arg3);
    }
};

#endif

template<typename Functor>
two_or_three_args_functor<Functor> wrap_two_or_three_args_functor(Functor functor)
{
    return two_or_three_args_functor<Functor>(functor);
}

template<size_t Size = 128>
class buffered_writer
{
    MJW_STATIC_ASSERT(Size != 0, "Illegal instantiation of buffered_writer");

private:

    std::ostream& m_stream;
    char m_buffer[Size];
    size_t m_offset;

    buffered_writer(const buffered_writer &);
    buffered_writer &operator=(const buffered_writer &);

public:

    explicit buffered_writer(std::ostream& stream) :
        m_stream(stream),
        m_offset(0)
    {
    }

    buffered_writer& operator<<(char c)
    {
        if (m_offset == Size)
        {
            flush();
        }

        m_buffer[m_offset++] = c;

        return *this;
    }

    template<size_t N>
    buffered_writer& operator<<(const char (&str)[N])
    {
        MJW_STATIC_ASSERT(N != 0, "Illegal instantiation of buffered_writer::operator<<(const char (&str)[N])");

        for (size_t i = 0; i < N - 1; i++)
        {
            operator<<(str[i]);
        }

        return *this;
    }

    void flush()
    {
        m_stream.write(m_buffer, m_offset);

        m_offset = 0;
    }
};

namespace
{

void adjust_stream_settings(std::ostream& stream)
{
    stream.imbue(std::locale::classic());
    stream << std::resetiosflags(std::ios::showpoint | std::ios::showpos);
    stream << std::dec << std::setw(0);
}

void write_quoted_string(std::ostream& stream, const char* str)
{
    stream << std::hex << std::right << std::setfill('0');

    buffered_writer<> writer(stream);

    writer << '"';

    while (*str != '\0')
    {
        switch (*str)
        {
        case '"':
            writer << "\\\"";
            break;

        case '\\':
            writer << "\\\\";
            break;

        case '\n':
            writer << "\\n";
            break;

        case '\r':
            writer << "\\r";
            break;

        case '\t':
            writer << "\\t";
            break;

        default:
            if ((*str > 0 && *str < 32) || *str == 127) // ASCII control characters (NUL is not supported)
            {
                writer << "\\u";

                writer.flush();
                stream << std::setw(4) << static_cast<unsigned>(*str);
            }
            else
            {
                writer << *str;
            }
            break;
        }
        str++;
    }

    writer << '"';

    writer.flush();

    stream << std::dec;
}

} // unnamed namespace

template<typename InputIt>
struct range
{
    InputIt begin;
    InputIt end;
};

template<typename InputIt>
range<InputIt> make_range(InputIt begin, InputIt end)
{
    const range<InputIt> range = { begin, end };

    return range;
}

template<typename InputIt, typename ValueWriter>
class range_writer
{
private:

    ValueWriter m_value_writer;

public:

    explicit range_writer(const ValueWriter& value_writer) :
        m_value_writer(value_writer)
    {
    }

    void operator()(std::ostream& stream, const range<InputIt>& range, const writer_configuration& configuration) const
    {
        write_array(stream, range.begin, range.end, m_value_writer, configuration);
    }
};

} // namespace detail

class writer
{
private:

    enum status
    {
        EMPTY,
        OPEN,
        CLOSED
    };

    bool m_array;
    status m_status;
    std::ostream* m_stream;
    writer_configuration m_configuration;

    enum pretty_print_token
    {
        BEFORE_ELEMENT,
        AFTER_COLON,
        BEFORE_CLOSING_BRACKET
    };

    void write_pretty_print_token(pretty_print_token token)
    {
        if (!m_configuration.pretty_printing())
        {
            return;
        }

        detail::buffered_writer<16> writer(*m_stream);

        if ((token == BEFORE_ELEMENT) || ((token == BEFORE_CLOSING_BRACKET) && (m_status != EMPTY)))
        {
            const size_t base_depth = (token == BEFORE_ELEMENT) ? 1 : 0;
            const size_t no_indent_characters = m_configuration.use_tabs() ?
                    (base_depth + m_configuration.nesting_level()) :
                    (base_depth + m_configuration.nesting_level()) * m_configuration.indent_spaces();

            writer << '\n';

            for (size_t i = 0; i < no_indent_characters; i++)
            {
                writer << ((m_configuration.use_tabs()) ? '\t' : ' ');
            }
        }
        else if (token == AFTER_COLON)
        {
            writer << ' ';
        }

        writer.flush();
    }

    void write_opening_bracket()
    {
        if (m_array)
        {
            *m_stream << '[';
        }
        else
        {
            *m_stream << '{';
        }
    }

    void write_closing_bracket()
    {
        write_pretty_print_token(BEFORE_CLOSING_BRACKET);

        if (m_array)
        {
            *m_stream << ']';
        }
        else
        {
            *m_stream << '}';
        }
    }

protected:

    void next_field()
    {
        if (m_status == EMPTY)
        {
            write_opening_bracket();
        }
        else if (m_status == OPEN)
        {
            *m_stream << ',';
        }

        write_pretty_print_token(BEFORE_ELEMENT);

        m_status = OPEN;
    }

    void write_field_name(const char* name)
    {
        detail::write_quoted_string(*m_stream, name);

        *m_stream << ':';

        write_pretty_print_token(AFTER_COLON);
    }

    template<typename V, typename ValueWriter>
    void write_helper(const char* field_name, const V& value, const ValueWriter& value_writer)
    {
        if (m_status == CLOSED)
        {
            return;
        }

        detail::adjust_stream_settings(*m_stream);

        next_field();

        if (field_name != NULL)
        {
            write_field_name(field_name);
        }

        const writer_configuration nested_object_configuration = m_configuration.increase_nesting_level();
        detail::wrap_two_or_three_args_functor(value_writer)(*m_stream, value, nested_object_configuration);
    }

    explicit writer(std::ostream& stream, bool array, const writer_configuration& configuration) :
        m_array(array),
        m_status(EMPTY),
        m_stream(&stream),
        m_configuration(configuration)
    {
    }

public:

    std::ostream& stream() const
    {
        return *m_stream;
    }

    const writer_configuration& configuration() const
    {
        return m_configuration;
    }

    void close()
    {
        if (m_status == CLOSED)
        {
            return;
        }

        detail::adjust_stream_settings(*m_stream);

        if (m_status == EMPTY)
        {
            write_opening_bracket();
        }

        write_closing_bracket();

        m_status = CLOSED;
    }

};

class object_writer;
class array_writer;

class object_writer : public writer
{
public:

    explicit object_writer(std::ostream& stream, const writer_configuration& configuration = writer_configuration()) :
        writer(stream, false, configuration)
    {
    }

    template<typename V>
    void write(const char* field_name, const V& value)
    {
        write_helper(field_name, value, default_value_writer<V>());
    }

    template<typename V, typename ValueWriter>
    void write(const char* field_name, const V& value, const ValueWriter& value_writer)
    {
        write_helper(field_name, value, value_writer);
    }

    template<typename InputIt>
    void write_array(const char* field_name, InputIt begin, InputIt end)
    {
        write_array(field_name, begin, end, default_value_writer<typename detail::get_value_type<InputIt>::type>());
    }

    template<typename InputIt, typename ValueWriter>
    void write_array(const char* field_name, InputIt begin, InputIt end, ValueWriter value_writer)
    {
        write(field_name, detail::make_range(begin, end), detail::range_writer<InputIt, ValueWriter>(value_writer));
    }

    object_writer nested_object(const char* field_name);

    array_writer nested_array(const char* field_name);

};

class array_writer : public writer
{
public:

    explicit array_writer(std::ostream& stream, const writer_configuration& configuration = writer_configuration()) :
        writer(stream, true, configuration)
    {
    }

    template<typename V>
    void write(const V& value)
    {
        write_helper(NULL, value, default_value_writer<V>());
    }

    template<typename V, typename ValueWriter>
    void write(const V& value, const ValueWriter& value_writer)
    {
        write_helper(NULL, value, value_writer);
    }

    template<typename InputIt>
    void write_array(InputIt begin, InputIt end)
    {
        write_array(begin, end, default_value_writer<typename detail::get_value_type<InputIt>::type>());
    }

    template<typename InputIt, typename ValueWriter>
    void write_array(InputIt begin, InputIt end, ValueWriter value_writer)
    {
        write(detail::make_range(begin, end), detail::range_writer<InputIt, ValueWriter>(value_writer));
    }

    object_writer nested_object();

    array_writer nested_array();

};

inline object_writer object_writer::nested_object(const char* field_name)
{
    detail::adjust_stream_settings(stream());

    next_field();
    write_field_name(field_name);

    return object_writer(stream(), configuration().increase_nesting_level());
}

inline array_writer object_writer::nested_array(const char* field_name)
{
    detail::adjust_stream_settings(stream());

    next_field();
    write_field_name(field_name);

    return array_writer(stream(), configuration().increase_nesting_level());
}

inline object_writer array_writer::nested_object()
{
    detail::adjust_stream_settings(stream());

    next_field();

    return object_writer(stream(), configuration().increase_nesting_level());
}

inline array_writer array_writer::nested_array()
{
    detail::adjust_stream_settings(stream());

    next_field();

    return array_writer(stream(), configuration().increase_nesting_level());
}

template<>
struct default_value_writer<null_t>
{
    void operator()(std::ostream& stream, null_t) const
    {
        stream << "null";
    }
};

#if MJW_CPP11_SUPPORTED
template<>
struct default_value_writer<std::nullptr_t>
{
    void operator()(std::ostream& stream, std::nullptr_t) const
    {
        default_value_writer<null_t>()(stream, null);
    }
};
#endif

template<typename IntegralType>
struct default_value_writer<
        IntegralType,
        typename detail::enable_if<MJW_LIB_NS::is_integral<IntegralType>::value && !MJW_LIB_NS::is_same<IntegralType, bool>::value>::type>
{
    void operator()(std::ostream& stream, IntegralType value) const
    {
        // the unary plus is used here to force chars to be printed as integers
        stream << +value;
    }
};

template<>
struct default_value_writer<bool>
{
    void operator()(std::ostream& stream, bool value) const
    {
        if (value)
        {
            stream << "true";
        }
        else
        {
            stream << "false";
        }
    }
};

template<typename FloatingPoint>
struct default_value_writer<
        FloatingPoint,
        typename detail::enable_if<MJW_LIB_NS::is_floating_point<FloatingPoint>::value>::type>
{
    void operator()(std::ostream& stream, FloatingPoint value) const
    {
        // Numeric values that cannot be represented as sequences of digits
        // (such as Infinity and NaN) are not permitted in JSON
        if (!MJW_ISFINITE(value))
        {
            default_value_writer<null_t>()(stream, null); // falling back to null
        }
        else
        {
            stream << value;
        }
    }
};

template<>
struct default_value_writer<char*>
{
    void operator()(std::ostream& stream, const char* str) const
    {
        detail::write_quoted_string(stream, str);
    }
};

template<>
struct default_value_writer<const char*> : public default_value_writer<char*>
{
};

template<size_t N>
struct default_value_writer<char[N]> : public default_value_writer<char*>
{
};

template<size_t N>
struct default_value_writer<const char[N]> : public default_value_writer<char*>
{
};

template<>
struct default_value_writer<std::string>
{
    void operator()(std::ostream& stream, const std::string& str) const
    {
        default_value_writer<char*>()(stream, str.c_str());
    }
};

template<typename InputIt>
void write_array(
        std::ostream& stream,
        InputIt begin, InputIt end,
        const writer_configuration& configuration)
{
    write_array(stream, begin, end, default_value_writer<typename detail::get_value_type<InputIt>::type>(), configuration);
}

template<typename InputIt, typename ValueWriter>
void write_array(
        std::ostream& stream,
        InputIt begin, InputIt end,
        const ValueWriter& value_writer,
        const writer_configuration& configuration)
{
    array_writer writer(stream, configuration);

    for (InputIt it = begin; it != end; ++it)
    {
        writer.write(*it, value_writer);
    }

    writer.close();
}

} // namespace minijson

#endif // MINIJSON_WRITER_H
